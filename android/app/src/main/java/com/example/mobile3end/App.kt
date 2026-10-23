package com.example.mobile3end

import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.mobile3end.crash.CrashDemoItems
import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.lifecycle.AppLifecycle
import com.example.mobile3end.lifecycle.LogComposition
import com.example.mobile3end.lifecycle.LogLifecycle
import com.example.mobile3end.lifecycle.ThreadDemoItems
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.SampleData
import com.example.mobile3end.ui.FileDetailScreen
import com.example.mobile3end.ui.FileListScreen
import com.example.mobile3end.ui.FileListViewModel
import com.example.mobile3end.web.H5Case
import com.example.mobile3end.web.H5Screen
import kotlinx.coroutines.flow.StateFlow

// 路由用字符串，和 vue-router 的 path 写法一样：`detail/:id` 在这里写成 `detail/{id}`
private const val ROUTE_LIST = "list"
private const val ROUTE_DETAIL = "detail/{id}"
// M4：可选参数写成查询串，≈ vue-router 的 query
private const val ROUTE_H5 = "h5?case={case}"

/**
 * @param stage 见 Stage.kt。测试会显式传，不受 STAGE 影响
 * @param listViewModelFactory M2 起列表的数据来源。默认连 mock 服务，测试换成假的
 * @param appState M4 起推给 H5 的前后台状态。默认来自 AppLifecycle（M3），测试换成假的
 */
@Composable
fun App(
    navController: NavHostController = rememberNavController(),
    stage: Int = STAGE,
    listViewModelFactory: ViewModelProvider.Factory? = null,
    appState: StateFlow<String?>? = null,
) {
    if (stage < 2) {
        Routes(
            navController,
            list = { onOpen -> FileListScreen(files = SampleData.files, onOpen = onOpen) },
            find = SampleData::find,
        )
        return
    }

    // ViewModel 在 NavHost 外面拿：作用域是 Activity，列表页和详情页共用同一个
    val context = LocalContext.current
    // M3 起：进程级前后台监听（ProcessLifecycleOwner），全进程装一次。回前台刷新的信号从这里交给 ViewModel
    if (stage >= 3) AppLifecycle.install()
    val vm: FileListViewModel = viewModel(
        factory = listViewModelFactory
            ?: if (stage >= 3) FileListViewModel.factory(context, refreshRequests = AppLifecycle.refreshRequests)
            else FileListViewModel.factory(context),
    )
    // collectAsStateWithLifecycle：App 退到后台时停止收集，回前台再接上。类比页面隐藏时暂停订阅
    val state by vm.state.collectAsStateWithLifecycle()
    val order by vm.order.collectAsStateWithLifecycle()

    if (stage >= 3) LogComposition("App")

    Routes(
        navController,
        list = { onOpen ->
            if (stage >= 3) {
                LogComposition("FileListScreen")
                LogLifecycle("FileListScreen")
            }
            FileListScreen(
                state = state,
                order = order,
                onOrderChange = vm::setOrder,
                onOpen = onOpen,
                onRetry = vm::retry,
                extraActions = {
                    if (stage >= 4) {
                        TextButton(
                            onClick = { navController.navigate(h5Route(H5Case.NORMAL)) },
                            modifier = Modifier.testTag("open-h5"),
                        ) { Text("H5") }
                    }
                    if (stage >= 3) {
                        DemoMenu(
                            showCrash = stage >= 5,
                            onOpenBlankH5 = { navController.navigate(h5Route(H5Case.BLANK)) },
                        )
                    }
                },
            )
        },
        find = { id -> (state as? ListUiState.Loaded)?.files?.firstOrNull { it.id == id } },
        h5 = if (stage < 4) null else { case, onBack ->
            H5Screen(
                initialCase = H5Case.of(case),
                onBack = onBack,
                appState = appState ?: AppLifecycle.appState,
                captureH5Errors = stage >= 5,
            )
        },
        logPages = stage >= 3,
    )
}

private fun h5Route(case: H5Case) = ROUTE_H5.replace("{case}", case.key)

/** 列表页右上角「⋮」：M3 的主线程演示，M5 的崩溃演示 */
@Composable
private fun DemoMenu(showCrash: Boolean, onOpenBlankH5: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    TextButton(onClick = { expanded = true }, modifier = Modifier.testTag("demo-menu")) { Text("⋮") }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        ThreadDemoItems(onPicked = { expanded = false })
        if (showCrash) CrashDemoItems(onPicked = { expanded = false }, onOpenBlankH5 = onOpenBlankH5)
    }
}

/** 路由表。列表页长什么样、详情页按 id 去哪找文件，由调用方按阶段决定 */
@Composable
private fun Routes(
    navController: NavHostController,
    list: @Composable (onOpen: (FileItem) -> Unit) -> Unit,
    find: (String?) -> FileItem?,
    h5: (@Composable (case: String?, onBack: () -> Unit) -> Unit)? = null,
    logPages: Boolean = false,
) {
    NavHost(navController = navController, startDestination = ROUTE_LIST) {
        composable(ROUTE_LIST) {
            list(
                // 空 M1-6：跳到这个文件的详情页。提示 1：把路由模板里的 {id} 换成真实值
                { file ->
                    navController.navigate(ROUTE_DETAIL.replace("{id}", file.id))
                },
            )
        }
        composable(ROUTE_DETAIL) { backStackEntry ->
            // 空 M1-7：从路由参数里取出 id。提示 1：backStackEntry.arguments 是个 Bundle
            val id: String? = backStackEntry.arguments?.getString("id")
            if (logPages) {
                LogComposition("FileDetailScreen")
                LogLifecycle("FileDetailScreen")
            }
            FileDetailScreen(
                file = find(id),
                // 空 M1-8：返回列表页。提示 1：返回 ≠ 再跳一次
                onBack = { navController.popBackStack() },
            )
        }
        if (h5 != null) {
            composable(ROUTE_H5) { backStackEntry ->
                if (logPages) LogLifecycle("H5Screen")
                h5(backStackEntry.arguments?.getString("case"), { navController.popBackStack() })
            }
        }
    }
}
