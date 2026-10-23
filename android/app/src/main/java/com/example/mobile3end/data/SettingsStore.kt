package com.example.mobile3end.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.example.mobile3end.model.SortOrder
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * 排序选择持久化。DataStore 是 SharedPreferences 的替代品：
 * - 读是一个 Flow，值变了会再推一次（类比 Pinia 的 store + watch）
 * - 写是 suspend 函数，在后台线程落盘，不会卡主线程（SharedPreferences.commit() 会）
 *
 * 和 localStorage 的差别：localStorage 是同步的，DataStore 读写都是异步的
 */
class SettingsStore(private val dataStore: DataStore<Preferences>) {

    private val orderKey = stringPreferencesKey("sort_order")

    // 空 M2-5：当前排序。没存过、或者存的值认不出来（比如老版本存了个已删除的枚举名）时用 NAME
    // 提示 1：dataStore.data 是 Flow<Preferences>，用 .map { prefs -> ... } 转成 Flow<SortOrder>；prefs[orderKey] 可能是 null
    val order: Flow<SortOrder>
        get() = dataStore.data.map { prefs ->
            val stored = prefs[orderKey]
            if (stored == null) {
                SortOrder.NAME
            } else {
                runCatching { SortOrder.valueOf(stored) }.getOrDefault(SortOrder.NAME)
            }
    }

    // 空 M2-6：保存排序
    // 提示 1：dataStore.edit { prefs -> ... }，存枚举的 name
    suspend fun setOrder(order: SortOrder) {
        dataStore.edit { prefs ->
            prefs[orderKey] = order.name
        }
    }
}
