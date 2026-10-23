package com.example.mobile3end

// 现在做到哪个里程碑。决定 App 的接线：
// - 1：列表用写死的 SampleData，排序只活在内存里
// - 2：列表来自网络 + 缓存，排序持久化
// 开始新里程碑时改这个数。测试不看它，各自传自己要的值
const val STAGE = 2

// 模拟器里 10.0.2.2 指向 Mac 本机（模拟器自己的 localhost 是模拟器）。真机改成 Mac 的局域网 IP
const val MOCK_BASE_URL = "http://10.0.2.2:8000"
