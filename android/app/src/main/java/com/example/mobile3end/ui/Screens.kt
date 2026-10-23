package com.example.mobile3end.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.SortOrder
import com.example.mobile3end.model.formatSize
import com.example.mobile3end.model.formatTime
import com.example.mobile3end.model.iconOf
import com.example.mobile3end.model.sortFiles

/**
 * M1 版：数据写死，排序状态由自己持有。
 * M2 起状态「提升」到 ViewModel，真正的界面在下面那个重载里，这个只是把 M1 的状态接上去
 */
@Composable
fun FileListScreen(files: List<FileItem>, onOpen: (FileItem) -> Unit) {
    // 空 M1-2：当前排序，初始为 NAME。旋转屏幕 / Activity 重建后要保持
    // 提示 1：remember 有一个能活过重建的版本
    val orderState: MutableState<SortOrder> = rememberSaveable { mutableStateOf(SortOrder.NAME) }
    var order by orderState

    FileListScreen(
        state = ListUiState.Loaded(files),
        order = order,
        onOrderChange = { order = it },
        onOpen = onOpen,
    )
}

/**
 * 无状态版本：要显示什么、排序是什么，全由调用方给；用户操作通过回调交出去。
 * 类比 Vue 的受控组件：props 进，emit 出
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileListScreen(
    state: ListUiState,
    order: SortOrder,
    onOrderChange: (SortOrder) -> Unit,
    onOpen: (FileItem) -> Unit,
    onRetry: () -> Unit = {},
    /** M3 起右上角多出来的入口（演示菜单、H5），由 App 按阶段决定 */
    extraActions: @Composable RowScope.() -> Unit = {},
) {
    val files = (state as? ListUiState.Loaded)?.files.orEmpty()

    // 空 M1-3：排好序的列表。只在 files 或 order 变化时重新排序
    // 提示 1：remember 可以带依赖参数，类似 Vue 的 computed
    val sorted: List<FileItem> = sortFiles(files, order)

    // 空 M1-4：列表滚动状态。进详情页再返回时滚动位置不能丢
    // 提示 1：rememberXxxState()
    val listState: LazyListState = rememberLazyListState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("我的文件") },
                actions = {
                    TextButton(
                        onClick = { onOrderChange(if (order == SortOrder.NAME) SortOrder.TIME else SortOrder.NAME) },
                        modifier = Modifier.testTag("sort"),
                    ) { Text("排序：${order.label}") }
                    extraActions()
                },
            )
        },
    ) { innerPadding ->
        if (sorted.isEmpty()) {
            StatusView(
                state = state,
                onRetry = onRetry,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            )
            return@Scaffold
        }
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .testTag("file-list"),
        ) {
            // 空 M1-5：给每一行一个稳定的 key。提示 1：Vue v-for 的 :key
            items(sorted, key = { it.id.toString() }) { file ->
                FileRow(file, onClick = { onOpen(file) })
                HorizontalDivider()
            }
        }
    }
}

// 空 M2-8：列表之外的三种状态，各自居中显示
// - Loading：转圈（CircularProgressIndicator），testTag "loading"
// - Failed：文案「加载失败」+ state.message + 「重试」按钮（testTag "retry"，点了调 onRetry）
// - Loaded 但为空：文案「没有文件」，testTag "empty"
// 提示 1：when (state) { is ListUiState.Loading -> ... }；居中用 Box(modifier, contentAlignment = Alignment.Center)
@Composable
private fun StatusView(state: ListUiState, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        when (state) {
            is ListUiState.Loading -> {
                CircularProgressIndicator(modifier = Modifier.testTag("loading"))
            }
            is ListUiState.Failed -> {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("加载失败")
                    Text(state.message)
                    Button(
                        onClick = onRetry,
                        modifier = Modifier.testTag("retry"),
                    ) { Text("重试") }
                }
            }
            is ListUiState.Loaded -> {
                Text("没有文件", modifier = Modifier.testTag("empty"))
            }
        }
    }
}

@Composable
private fun FileRow(file: FileItem, onClick: () -> Unit) {
    ListItem(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        leadingContent = { Text(iconOf(file.type)) },
        headlineContent = { Text(file.name) },
        supportingContent = {
            Row {
                if (file.size > 0) Text(formatSize(file.size) + " · ")
                Text(formatTime(file.mtime))
            }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileDetailScreen(file: FileItem?, onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("详情") },
                navigationIcon = { TextButton(onClick = onBack) { Text("← 返回") } },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .padding(16.dp),
        ) {
            if (file == null) {
                Text("文件不存在", modifier = Modifier.testTag("detail-name"))
                return@Column
            }
            Text("${iconOf(file.type)} ${file.name}", modifier = Modifier.testTag("detail-name"))
            Text("id：${file.id}")
            Text("类型：${file.type.name.lowercase()}")
            Text("大小：${if (file.size > 0) formatSize(file.size) else "—"}")
            Text("修改时间：${formatTime(file.mtime)}")
        }
    }
}
