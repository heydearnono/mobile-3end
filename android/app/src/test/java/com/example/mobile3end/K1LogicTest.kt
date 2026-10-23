package com.example.mobile3end

import com.example.mobile3end.data.ListUiState
import com.example.mobile3end.data.encodeFiles
import com.example.mobile3end.k1.BridgeResult
import com.example.mobile3end.k1.describe
import com.example.mobile3end.k1.displayName
import com.example.mobile3end.k1.failedMessage
import com.example.mobile3end.k1.fetchOrNull
import com.example.mobile3end.k1.firstImageSize
import com.example.mobile3end.k1.isMedia
import com.example.mobile3end.k1.loadBoth
import com.example.mobile3end.k1.parseMtimeMs
import com.example.mobile3end.k1.parseOrNull
import com.example.mobile3end.k1.rename
import com.example.mobile3end.k1.sizeLabel
import com.example.mobile3end.k1.summary
import com.example.mobile3end.k1.toJs
import com.example.mobile3end.k1.totalSize
import com.example.mobile3end.k1.withLog
import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** K1 Kotlin 语言专项，全是 JVM 单测。方法名前缀 = 覆盖的空 */
class K1LogicTest {

    private val folder = FileItem("d1", "工作资料", FileType.FOLDER, 0, 1760500000)
    private val doc = FileItem("f1", "季度复盘.docx", FileType.DOC, 482133, 1760830000)
    private val image = FileItem("f2", "猫.heic", FileType.IMAGE, 2097152, 1759900000)
    private val video = FileItem("f3", "会议录音.m4a", FileType.VIDEO, 15728640, 1757500000)

    // ---------- 示例：data class 的 == 比的是字段 ----------

    @Test
    fun k1_0_dataClassEqualsComparesFields() {
        val a = FileItem("x", "x", FileType.DOC, 1, 1)
        val b = FileItem("x", "x", FileType.DOC, 1, 1)
        assertTrue("== 比字段值", a == b)
        assertFalse("=== 比引用", a === b)
    }

    // ---------- 第 1 节：表达式 ----------

    @Test
    fun k1_1_sizeLabel() {
        assertEquals("—", sizeLabel(0))
        assertEquals("1 B", sizeLabel(1))
        assertEquals("1023 B", sizeLabel(1023))
        assertEquals("1.0 KB", sizeLabel(1024))
        assertEquals("2.0 MB", sizeLabel(2097152))
    }

    @Test
    fun k1_2_parseOrNull() {
        assertEquals(listOf(doc), parseOrNull(encodeFiles(listOf(doc))))
        assertNull(parseOrNull("<html>502</html>"))
        assertNull(parseOrNull("""{"files":[{"id":"x"}]}"""))
    }

    @Test
    fun k1_3_describeLambda() {
        assertEquals("📁 工作资料", describe(folder))
        assertEquals(listOf("📄 季度复盘.docx", "🖼️ 猫.heic"), listOf(doc, image).map(describe))
    }

    // ---------- 第 2 节：空安全 ----------

    @Test
    fun k1_4_displayName() {
        assertEquals("工作资料", displayName(folder))
        assertEquals("文件不存在", displayName(null))
    }

    @Test
    fun k1_5_firstImageSize() {
        assertEquals(2097152L, firstImageSize(listOf(folder, doc, image, video)))
        assertEquals(0L, firstImageSize(listOf(folder, doc)))
        assertEquals(0L, firstImageSize(emptyList()))
        assertEquals(0L, firstImageSize(null))
    }

    @Test
    fun k1_6_failedMessage() {
        assertEquals("HTTP 500", failedMessage(ListUiState.Failed("HTTP 500")))
        assertNull(failedMessage(ListUiState.Loading))
        assertNull(failedMessage(ListUiState.Loaded(listOf(doc))))
    }

    // ---------- 第 3 节：尾随 lambda、作用域函数 ----------

    @Test
    fun k1_7_withLogReturnsBlockResult() {
        val logs = mutableListOf<String>()
        val result = withLog(logs, "load") {
            logs += "working"
            42
        }
        assertEquals(42, result)
        assertEquals(listOf("start load", "working", "end load"), logs)
    }

    @Test
    fun k1_7_withLogStillEndsOnException() {
        val logs = mutableListOf<String>()
        try {
            withLog(logs, "boom") { error("炸了") }
            fail("异常应该照常抛出来")
        } catch (e: IllegalStateException) {
            assertEquals("炸了", e.message)
        }
        assertEquals(listOf("start boom", "end boom"), logs)
    }

    @Test
    fun k1_8_summary() {
        assertEquals("📁 工作资料\n🎬 会议录音.m4a\n", summary(listOf(folder, video)))
        assertEquals("", summary(emptyList()))
    }

    @Test
    fun k1_9_parseMtimeMs() {
        assertEquals(1760500000000L, parseMtimeMs("1760500000"))
        assertNull(parseMtimeMs(null))
        assertNull(parseMtimeMs("昨天"))
        assertNull(parseMtimeMs(""))
    }

    // ---------- 第 4 节：data class、sealed ----------

    @Test
    fun k1_10_renameCopies() {
        val renamed = rename(doc, "Q3复盘.docx")
        assertEquals(FileItem("f1", "Q3复盘.docx", FileType.DOC, 482133, 1760830000), renamed)
        assertNotSame(doc, renamed)
        assertEquals("原对象不变", "季度复盘.docx", doc.name)
    }

    @Test
    fun k1_11_toJsOk() {
        assertEquals(
            """window.__bridgeCallback({"id":"1","ok":true,"data":{"platform":"android"}})""",
            toJs("1", BridgeResult.Ok("""{"platform":"android"}""")),
        )
    }

    @Test
    fun k1_11_toJsErr() {
        assertEquals(
            """window.__bridgeCallback({"id":"7","ok":false,"error":{"code":"METHOD_NOT_FOUND","message":"no such method: foo"}})""",
            toJs("7", BridgeResult.Err("METHOD_NOT_FOUND", "no such method: foo")),
        )
    }

    // ---------- 第 5 节：扩展 ----------

    @Test
    fun k1_12_isMedia() {
        assertEquals(listOf(false, false, true, true), listOf(folder, doc, image, video).map { it.isMedia() })
    }

    @Test
    fun k1_13_totalSize() {
        assertEquals(482133L + 2097152L + 15728640L, listOf(folder, doc, image, video).totalSize)
        assertEquals(0L, emptyList<FileItem>().totalSize)
    }

    // ---------- 第 6 节：协程 ----------
    // runTest 用虚拟时间：delay(1000) 不会真的等 1 秒，currentTime 是虚拟时钟走过的毫秒数

    @Test
    fun k1_14_loadBothRunsConcurrently() = runTest {
        val files = loadBoth(
            first = { delay(1000); listOf(doc) },
            second = { delay(1000); listOf(image) },
        )
        assertEquals("first 在前", listOf(doc, image), files)
        assertEquals("两个各等 1 秒，并发执行总共应该是 1 秒，不是 2 秒", 1000L, currentTime)
    }

    @Test
    fun k1_14_orderFollowsArgumentsNotFinishTime() = runTest {
        val files = loadBoth(
            first = { delay(2000); listOf(doc) },
            second = { delay(500); listOf(image) },
        )
        assertEquals("second 先回来，结果也要 first 在前", listOf(doc, image), files)
    }

    @Test
    fun k1_15_fetchOrNull() = runTest {
        assertEquals(1, fetchOrNull(2000) { delay(1000); 1 })
        assertNull("超时应返回 null", fetchOrNull(500) { delay(1000); 1 })
        assertEquals("超时就放弃，不再等 block 跑完", 1500L, currentTime)
    }
}
