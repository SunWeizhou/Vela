# Phase 2: DI Container + Unified Error Handling

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** 引入轻量 DI 容器消除服务创建点散落问题 + 建立统一错误类型并让 UI 层可展示错误。

**Architecture:** (1) `VelaServices` — 一个 struct 持有所有共享服务实例，在 AppCoordinator 创建一次，通过 SwiftUI `.environment()` 传递；(2) `VelaError` enum + `.velaErrorAlert()` ViewModifier — 关键路径的 `try?` 替换为 throw → catch → 发布到 UI。

**Tech Stack:** Swift, SwiftUI, SwiftData（无新依赖）

---

## 现状总结

- 10 个 `.shared` 单例散布全代码库
- 8 处直接 `ClassName()` 内联构造，每个消费者创建自己的实例
- `try?` 在 Health/AI 层广泛使用（50+ 处），错误静默丢弃
- 无统一错误类型，UI 层无法区分"无数据"vs"查询失败"

## 设计决策

**DI 用 struct + Environment，不用 actor/container：**
- SwiftUI 原生支持 `@EnvironmentObject`，无需第三方库
- struct 保证线程安全（SwiftUI 的 Environment 在 MainActor 上传递）
- 保持简单：单例仍保留给真正全局的（`NotificationService`、`VelaAppState`、`KeychainService`、`HealthStoreProvider`）

**错误处理聚焦两条关键路径：**
1. HealthKit 查询失败 → 用户应看到"无法读取健康数据"
2. LLM API 调用失败 → 用户应看到"AI 服务暂时不可用"
3. 文件 I/O（Wiki）失败 → 静默记录日志即可（非用户可见）

---

## 文件变更清单

| 操作 | 文件 | 职责 |
|------|------|------|
| **Create** | `Core/Utilities/VelaError.swift` | 统一错误类型 + 本地化错误描述 |
| **Create** | `Core/Utilities/VelaServices.swift` | 服务容器 struct |
| **Create** | `Core/Extensions/View+VelaErrorAlert.swift` | 错误提示 ViewModifier |
| **Modify** | `App/AppCoordinator.swift` | 创建 VelaServices，注入 Environment |
| **Modify** | `Features/SharedComponents/DashboardViewModel.swift` | 接收 VelaServices，发布错误状态 |
| **Modify** | `Health/Services/HealthKitQueryService.swift` | 关键查询方法抛 VelaError 替代 try? |
| **Modify** | `AI/Provider/DeepSeekProvider.swift` | 网络错误映射为 VelaError |
| **Modify** | `Features/Coach/CoachChatPanel.swift` | 通过 Environment 获取服务，展示错误 |
| **Modify** | `AI/Proactive/EveningWikiSyncAgent.swift` | 通过注入获取服务 |
| **Check** | 使用 `.shared` 的视图文件 | 改为 `@EnvironmentObject` |

---

### Task 1: 创建 VelaError 统一错误类型

**Files:**
- Create: `VelaApp/Core/Utilities/VelaError.swift`

```swift
import Foundation

/// Unified error type for Vela. All service-layer errors map to one of these cases
/// so the UI layer can display localized, actionable messages.
enum VelaError: Error, LocalizedError, Identifiable {
    var id: String { "\(code)-\(localizedDescription)" }

    // MARK: - HealthKit

    /// HealthKit authorization denied or restricted
    case healthKitUnauthorized
    /// HealthKit query failed (e.g. database locked, sensor unavailable)
    case healthKitQueryFailed(sampleType: String, underlying: Error? = nil)
    /// HealthKit data unavailable (no watch, no sensor)
    case healthKitDataUnavailable(sampleType: String)

    // MARK: - Network / AI

    /// DeepSeek API returned an error response
    case aiServiceError(statusCode: Int, message: String)
    /// Network request timed out or connection failed
    case networkUnavailable(underlying: Error? = nil)
    /// LLM response was empty or unparseable
    case aiResponseEmpty

    // MARK: - Persistence

    /// SwiftData save/load failed
    case persistenceFailed(operation: String, underlying: Error? = nil)
    /// Wiki file read/write failed
    case wikiFileError(path: String, underlying: Error? = nil)

    // MARK: - General

    /// Unknown / unexpected error
    case unknown(underlying: Error? = nil)

    // MARK: - Computed

    var code: Int {
        switch self {
        case .healthKitUnauthorized: return 1001
        case .healthKitQueryFailed: return 1002
        case .healthKitDataUnavailable: return 1003
        case .aiServiceError: return 2001
        case .networkUnavailable: return 2002
        case .aiResponseEmpty: return 2003
        case .persistenceFailed: return 3001
        case .wikiFileError: return 3002
        case .unknown: return 9999
        }
    }

    var errorDescription: String? {
        let lang = AppLanguage.stored
        let isChinese = lang.isChinese

        switch self {
        case .healthKitUnauthorized:
            return isChinese ? "健康数据未授权" : "Health Data Not Authorized"
        case .healthKitQueryFailed(let type, _):
            // let type = sampleType
            return isChinese ? "无法读取\(type)数据" : "Failed to read \(type) data"
        case .healthKitDataUnavailable(let type):
            return isChinese ? "\(type)数据不可用" : "\(type) data unavailable"
        case .aiServiceError(let code, _):
            return isChinese ? "AI 服务错误 (\(code))" : "AI Service Error (\(code))"
        case .networkUnavailable:
            return isChinese ? "网络连接失败" : "Network Unavailable"
        case .aiResponseEmpty:
            return isChinese ? "AI 未返回内容" : "AI returned empty response"
        case .persistenceFailed(let op, _):
            // let op = operation
            return isChinese ? "数据\(op)失败" : "Data \(op) failed"
        case .wikiFileError(let path, _):
            return isChinese ? "Wiki 文件错误" : "Wiki file error"
        case .unknown:
            return isChinese ? "未知错误" : "Unknown error"
        }
    }

    var recoverySuggestion: String? {
        let lang = AppLanguage.stored
        let isChinese = lang.isChinese

        switch self {
        case .healthKitUnauthorized:
            return isChinese
                ? "请在系统设置中授权 Apple 健康数据访问"
                : "Please authorize Apple Health access in System Settings"
        case .healthKitQueryFailed:
            return isChinese
                ? "请确保 Apple Watch 已配对并正在同步数据"
                : "Make sure your Apple Watch is paired and syncing data"
        case .healthKitDataUnavailable:
            return isChinese
                ? "佩戴 Apple Watch 睡觉或运动后数据将自动出现"
                : "Data will appear after wearing your Apple Watch to sleep or exercise"
        case .aiServiceError:
            return isChinese
                ? "请稍后重试或在设置中检查 API Key"
                : "Please try again later or check your API key in Settings"
        case .networkUnavailable:
            return isChinese
                ? "请检查网络连接后重试"
                : "Please check your internet connection and try again"
        case .aiResponseEmpty:
            return isChinese
                ? "请重试或简化你的问题"
                : "Please try again or simplify your question"
        case .persistenceFailed:
            return isChinese
                ? "请重启 App 后重试"
                : "Please restart the app and try again"
        case .wikiFileError:
            return nil
        case .unknown:
            return isChinese
                ? "请重启 App 后重试"
                : "Please restart the app and try again"
        }
    }
}
```

---

### Task 2: 创建 VelaServices 容器

**Files:**
- Create: `VelaApp/Core/Utilities/VelaServices.swift`

```swift
import Foundation
import SwiftData

/// Lightweight service container. Created once in AppCoordinator, passed via SwiftUI Environment.
/// Services that are truly global (NotificationService, KeychainService, VelaAppState, HealthStoreProvider)
/// remain as singletons and are NOT included here.
@MainActor
final class VelaServices: ObservableObject {
    let queryService: HealthKitQueryService
    let refreshService: HealthDataRefreshService
    let contextBuilder: AIContextBuilder
    let wikiFileService: WikiFileService
    let webSearchService: WebSearchService
    let dailySummaryUseCase: DailySummaryUseCase

    /// Cache of DeepSeekProvider keyed by apiKey to avoid recreation
    private var providerCache: [String: DeepSeekProvider] = [:]

    init(
        queryService: HealthKitQueryService = HealthKitQueryService(),
        wikiFileService: WikiFileService = WikiFileService(),
        webSearchService: WebSearchService = WebSearchService()
    ) {
        self.queryService = queryService
        self.refreshService = HealthDataRefreshService(queryService: queryService)
        self.contextBuilder = AIContextBuilder()
        self.wikiFileService = wikiFileService
        self.webSearchService = webSearchService
        self.dailySummaryUseCase = DailySummaryUseCase(
            refreshService: refreshService,
            queryService: queryService
        )
    }

    func deepSeekProvider(apiKey: String) -> DeepSeekProvider {
        if let cached = providerCache[apiKey] {
            return cached
        }
        let provider = DeepSeekProvider(apiKey: apiKey)
        providerCache[apiKey] = provider
        return provider
    }
}
```

---

### Task 3: 创建错误提示 ViewModifier

**Files:**
- Create: `VelaApp/Core/Extensions/View+VelaErrorAlert.swift`

```swift
import SwiftUI

struct VelaErrorAlertModifier: ViewModifier {
    @Binding var error: VelaError?

    func body(content: Content) -> some View {
        content
            .alert(
                error?.errorDescription ?? "Error",
                isPresented: .init(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { err in
                Button("OK") { error = nil }
            } message: { err in
                if let suggestion = err.recoverySuggestion {
                    Text(suggestion)
                }
            }
    }
}

extension View {
    func velaErrorAlert(error: Binding<VelaError?>) -> some View {
        modifier(VelaErrorAlertModifier(error: error))
    }
}
```

---

### Task 4: 在 AppCoordinator 创建 VelaServices 并注入

**Files:**
- Modify: `VelaApp/App/AppCoordinator.swift`

将 `VelaServices` 加入 AppCoordinator，通过 `.environmentObject()` 传递给整个视图树。

在 AppCoordinator 中添加：
```swift
@StateObject private var services = VelaServices()
```

在 `VelaRootView()` 上添加：
```swift
VelaRootView()
    .environmentObject(dashboardVM)
    .environmentObject(services)
    .environment(\.locale, ...)
```

---

### Task 5: 改造 DashboardViewModel 使用注入服务 + 暴露错误

**Files:**
- Modify: `VelaApp/Features/SharedComponents/DashboardViewModel.swift`

- 移除 `private let useCase: DailySummaryUseCase = DailySummaryUseCase()` 
- 改为从 Environment 接收 `VelaServices`
- 添加 `@Published var currentError: VelaError?`
- `refresh()` 方法中 catch 错误并设置 `currentError`

---

### Task 6: 改造 CoachChatPanel 使用注入服务

**Files:**
- Modify: `VelaApp/Features/Coach/CoachChatPanel.swift`

- 移除 `private let contextBuilder = AIContextBuilder()`
- 移除内联的 `DeepSeekProvider(apiKey:)` 创建
- 改用 `@EnvironmentObject var services: VelaServices`
- 网络错误 catch → 设置本地 error 状态 → 显示错误提示

---

### Task 7: 改造 EveningWikiSyncAgent 和 MorningBriefScheduler

**Files:**
- Modify: `VelaApp/AI/Proactive/EveningWikiSyncAgent.swift`
- Modify: `VelaApp/AI/Proactive/MorningBriefScheduler.swift`

- `contextBuilder` 改从外部注入（via `runIfNeeded(services:)` 参数）
- `DeepSeekProvider` 创建改通过 `services.deepSeekProvider(apiKey:)`

---

### Task 8: 在关键 UI 视图添加错误提示

**Files:**
- Modify: `VelaApp/App/VelaRootView.swift` 或 `VelaApp/Features/Minimal/VelaMinimalShell.swift`

- 监听 `dashboardVM.currentError` 
- 使用 `.velaErrorAlert(error: $dashboardVM.currentError)` 

---

### Task 9: Build + Test + 真机冒烟

编译 → 测试 → 推送手机验证错误提示和正常流程。
