import Foundation

// S1 第 6 节：错误处理
//
//   Swift                                     Kotlin                                  TS
//   func f() throws -> T                      fun f(): T（不用声明）                  function f(): T（不用声明）
//   try f()                                   f()                                     f()
//   do { try f() } catch { error }            try { f() } catch (e: Exception) { }    try { f() } catch (e) { }
//   catch FileApiError.badStatus(let code)    catch (e: BadStatus)                    if (e instanceof ...)
//   try? f()（出错得 nil）                    runCatching { f() }.getOrNull()          —
//   try! f()（出错就崩）                      f()（没人 catch 就崩）                   f()（没人 catch 就崩）
//   Result<T, E>                              Result<T>                               —
//   throw FileApiError.badStatus(500)         throw BadStatus(500)                    throw new Error(...)
//
// - 会抛错的函数必须在签名上写 throws，调用的地方必须写 try。读代码时看到 try 就知道「这一行可能跳走」，
//   Kotlin / TS 里任何一行都可能抛，看不出来
// - 错误是遵守 Error 协议的任意类型，通常是 enum（工程里的 FileApiError），catch 可以像 switch 一样按 case 匹配
// - catch 的模式没覆盖所有可能时，最后要有一个不带模式的 catch（里面自动有个 error 常量），否则编译报错
// - try? 把「成功的值 / 抛错」变成「值 / nil」，丢掉了错误原因。M2-5 读缓存正适合用它（坏了就当没有）
// - Result 是标准库里的普通 enum：.success(值) / .failure(错误)。Result { try f() } 把调用结果包起来，
//   result.get() 再拆开（成功返回值、失败重新抛出）。TestSupport.swift 的 FakeRemote 就是这么用的
// - async 和 throws 可以一起：func fetch() async throws，调用写 try await（M2-3）
// - ObjC / 系统 API 抛的错误是 NSError，转一下 error as NSError 就能看 domain 和 code（M4-10）

/// 解析好的 H5 请求
struct BridgeRequest: Equatable {
    let id: String
    let method: String
}

enum BridgeParseError: Error, Equatable {
    /// 不是 JSON，或者是 JSON 但不是对象（比如是数组）
    case notJSON
    /// 缺字段，或者字段不是字符串。关联值是字段名
    case missingField(String)
}

// 空 S1-12：把 H5 发来的字符串 {"id":"1","method":"toast","params":{}} 解析成 BridgeRequest
// - 不是 JSON 对象：throw BridgeParseError.notJSON
// - 先检查 id 再检查 method，缺哪个 throw .missingField("id") / .missingField("method")
// 提示 1：JSONSerialization.jsonObject(with:) 自己也会 throw（抛的是 NSError），要把它也变成 .notJSON。
//         try? 加 as? 一起放进 guard let 是常见写法
func parseRequest(_ text: String) throws -> BridgeRequest {
    TODO("S1-12")
}

/// 回给 H5 的结果
enum BridgeReply: Equatable {
    case ok(data: [String: String])
    case err(code: String, message: String)
}

// 空 S1-13：调 parseRequest，把结果翻译成要回给 H5 的 BridgeReply：
// - 成功：.ok(data: ["method": 解析出的 method])
// - .notJSON：.err(code: "BAD_JSON", message: "")
// - .missingField(f)：.err(code: "MISSING_FIELD", message: f)
// 提示 1：do { let req = try ... } catch BridgeParseError.missingField(let f) { ... } catch { ... }；
//         也可以先 Result { try ... } 再 switch，两种都写一遍
func replyFor(_ text: String) -> BridgeReply {
    TODO("S1-13")
}
