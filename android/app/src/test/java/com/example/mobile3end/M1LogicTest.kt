package com.example.mobile3end

import com.example.mobile3end.model.FileItem
import com.example.mobile3end.model.FileType
import com.example.mobile3end.model.SortOrder
import com.example.mobile3end.model.sortFiles
import org.junit.Assert.assertEquals
import org.junit.Test

/** M1 纯逻辑检查，JVM 上跑，不需要模拟器。方法名前缀 = 覆盖的空 */
class M1LogicTest {

    private val input = listOf(
        FileItem("a", "a.txt", FileType.DOC, 1, 10),
        FileItem("F1", "F1", FileType.FOLDER, 0, 1),
        FileItem("b", "b.txt", FileType.DOC, 1, 30),
        FileItem("c", "c.png", FileType.IMAGE, 1, 20),
        FileItem("F2", "F2", FileType.FOLDER, 0, 5),
    )

    private fun ids(list: List<FileItem>) = list.map { it.id }

    @Test
    fun m1_0_nameOrder_givenAsExample() {
        assertEquals(listOf("F1", "F2", "a", "b", "c"), ids(sortFiles(input, SortOrder.NAME)))
    }

    @Test
    fun m1_1_timeOrder_newestFirst_foldersStillOnTop() {
        assertEquals(listOf("F2", "F1", "b", "c", "a"), ids(sortFiles(input, SortOrder.TIME)))
    }

    @Test
    fun m1_1_doesNotMutateInput() {
        val before = ids(input)
        sortFiles(input, SortOrder.TIME)
        assertEquals(before, ids(input))
    }
}
