package com.example.mobile3end

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.mobile3end.model.SampleData
import com.example.mobile3end.ui.FileListScreen
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * M1 UI 检查，需要模拟器。方法名前缀 = 覆盖的空。
 *
 * 依赖 SampleData 的排序结果（按名称 / 按时间）：
 * - 「Demo演示.mp4」名称序第 4 行，时间序最后一行（第 19 行）
 * - 「白屏率看板截图.png」名称序第 17 行，时间序第 4 行
 * - 「旅行vlog.mov」名称序第 15 行
 * 一屏约 10 行，所以「第 4 行」在首屏、「第 15 行以后」不在首屏。
 */
@RunWith(AndroidJUnit4::class)
class M1UiTest {

    @get:Rule
    val rule = createComposeRule()

    private fun row(name: String): SemanticsNodeInteraction = rule.onNodeWithText(name)

    private fun isOnScreen(name: String): Boolean =
        try {
            row(name).assertIsDisplayed(); true
        } catch (e: AssertionError) {
            false
        }

    @Composable
    private fun setList() = FileListScreen(files = SampleData.files, onOpen = {})

    @Test
    fun m1_2_sortOrderSurvivesRecreation() {
        val tester = StateRestorationTester(rule)
        tester.setContent { MaterialTheme { setList() } }
        rule.onNodeWithTag("sort").performClick()
        rule.onNodeWithTag("sort").assertTextContains("时间", substring = true)

        tester.emulateSavedInstanceStateRestore()

        rule.onNodeWithTag("sort").assertTextContains("时间", substring = true)
    }

    @Test
    fun m1_3_listResortsWhenOrderChanges() {
        rule.setContent { MaterialTheme { setList() } }
        assertFalse("名称序下「白屏率看板截图.png」不应在首屏", isOnScreen("白屏率看板截图.png"))

        rule.onNodeWithTag("sort").performClick()

        assertTrue("切到时间序后「白屏率看板截图.png」应在首屏", isOnScreen("白屏率看板截图.png"))
    }

    @Test
    fun m1_4_scrollPositionSurvivesRecreation() {
        val tester = StateRestorationTester(rule)
        tester.setContent { MaterialTheme { setList() } }
        rule.onNodeWithTag("file-list").performScrollToIndex(15)
        assertTrue(isOnScreen("旅行vlog.mov"))

        tester.emulateSavedInstanceStateRestore()

        assertTrue("恢复后应仍停在「旅行vlog.mov」附近", isOnScreen("旅行vlog.mov"))
    }

    @Test
    fun m1_5_scrollAnchorFollowsKeyAfterResort() {
        rule.setContent { MaterialTheme { setList() } }
        // 让「Demo演示.mp4」成为首个可见行，然后切排序：它会被挪到最后一行
        rule.onNodeWithTag("file-list").performScrollToIndex(4)
        assertTrue(isOnScreen("Demo演示.mp4"))

        rule.onNodeWithTag("sort").performClick()

        assertTrue(
            "有稳定 key 时，列表会跟着首个可见行走，「Demo演示.mp4」应仍可见",
            isOnScreen("Demo演示.mp4"),
        )
    }

    private lateinit var nav: NavHostController

    private fun setApp() = rule.setContent {
        nav = rememberNavController()
        MaterialTheme { App(nav, stage = 1) }
    }

    @Test
    fun m1_6_m1_7_openDetailShowsTappedFile() {
        setApp()
        row("Android学习笔记.md").performClick()

        assertEquals("detail/{id}", nav.currentDestination?.route)
        rule.onNodeWithTag("detail-name").assertTextContains("Android学习笔记.md", substring = true)
    }

    @Test
    fun m1_8_backPopsInsteadOfPushing() {
        setApp()
        row("Android学习笔记.md").performClick()
        rule.onNodeWithText("← 返回").performClick()
        rule.waitForIdle()

        assertEquals("list", nav.currentDestination?.route)
        assertNull("返回后栈里不应还有别的页面", nav.previousBackStackEntry)
    }

    @Test
    fun m1_e2e_backKeepsScrollPosition() {
        setApp()
        rule.onNodeWithTag("file-list").performScrollToIndex(15)
        row("旅行vlog.mov").performClick()
        rule.onNodeWithText("← 返回").performClick()
        rule.waitForIdle()

        assertTrue("从详情返回后应仍停在「旅行vlog.mov」附近", isOnScreen("旅行vlog.mov"))
    }
}
