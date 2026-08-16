# AppManager（本地应用与服务管理器）实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个运行在 macOS 上的原生 SwiftUI 应用，统一管理本地 App、自建 Web 服务与自定义命令，支持一键启动、健康监控、启停控制、分类整理、资源查看与自定义命令模板。

**Architecture:** SwiftUI + SwiftPM 命令行构建（不依赖 Xcode）。个人自用、无沙盒：Codable JSON 存储服务清单（Application Support），Process 执行 shell 命令，URLSession 做健康检查，ps 解析资源占用，@Observable 驱动 UI 状态，Swift Testing 做单元测试。

**Tech Stack:** Swift 6.3（swift-tools 6.0，macOS 14+ 平台目标）、SwiftUI、Swift Testing、Foundation（Process / URLSession / NSWorkspace / UserNotifications）

**环境前提（已核实）：** macOS 26.5.2，Swift 6.3.3（Command Line Tools），Homebrew/Docker/Node 已装，无 Xcode（因此全程用 swift build / swift run / swift test）。

---

## 文件结构

最终目标结构（每个文件一个明确职责）：

~~~
myapp/
├── Package.swift
├── .gitignore
├── scripts/
│   └── bundle-app.sh                  # P6：把可执行文件打包成 .app
├── Sources/AppManager/
│   ├── AppManagerApp.swift            # @main 入口 + 窗口激活策略
│   ├── Models/
│   │   ├── ServiceKind.swift          # 服务类型枚举（app/url/command）
│   │   ├── ManagedService.swift       # 服务模型（Codable）
│   │   └── ServiceStatus.swift        # 状态枚举（unknown/healthy/down）
│   ├── Storage/
│   │   └── ServiceStore.swift         # JSON 持久化 + @Observable
│   ├── Services/
│   │   ├── CommandRunner.swift        # Process 异步执行器
│   │   ├── HealthChecker.swift        # URL 健康检查
│   │   ├── ServiceController.swift    # 启动/停止/重启/状态编排
│   │   ├── ResourceMonitor.swift      # ps 解析 CPU/内存
│   │   ├── Placeholder.swift          # {var} 占位符替换
│   │   └── DashboardViewModel.swift   # 定时轮询调度
│   └── Views/
│       ├── ContentView.swift          # 主布局：侧边栏分类 + 服务列表
│       ├── ServiceListView.swift      # 列表 + 搜索过滤
│       ├── ServiceRowView.swift       # 单行：图标/状态/按钮
│       ├── ServiceDetailView.swift    # 详情 + 资源 + 输出
│       ├── EditServiceView.swift      # 新增/编辑表单
│       ├── CommandOutputView.swift    # 命令输出面板
│       └── SettingsView.swift         # 设置
├── Tests/AppManagerTests/
│   ├── CommandRunnerTests.swift
│   ├── HealthCheckerTests.swift
│   ├── ResourceMonitorTests.swift
│   ├── ServiceStoreTests.swift
│   ├── ServiceControllerTests.swift
│   └── PlaceholderTests.swift
└── docs/superpowers/plans/2026-08-16-app-manager.md
~~~

---

## P0：环境与项目骨架

### Task 0.1: 创建 Package.swift 与 .gitignore

**Files:**
- Create: Package.swift
- Create: .gitignore

- [ ] **Step 1: 写入 Package.swift**

~~~swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AppManager",
            path: "Sources/AppManager",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AppManagerTests",
            dependencies: ["AppManager"],
            path: "Tests/AppManagerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
~~~

> 说明：.swiftLanguageMode(.v5) 降低 Swift 6 严格并发报错门槛，个人项目可接受；目标平台 macOS 14 保证 @Observable/SwiftUI 新 API 可用。

- [ ] **Step 2: 写入 .gitignore**

~~~
.build/
.DS_Store
*.xcuserstate
*.app/
.swiftpm/
~~~

- [ ] **Step 3: 验证构建**

Run: swift build
Expected: 成功编译，无报错

- [ ] **Step 4: 提交**

~~~bash
git add Package.swift .gitignore
git commit -m "chore: init SwiftPM package skeleton"
~~~

### Task 0.2: 最小可运行 App

**Files:**
- Create: Sources/AppManager/AppManagerApp.swift
- Create: Sources/AppManager/Views/ContentView.swift

- [ ] **Step 1: 写入口（处理 CLI 启动时的窗口激活）**

~~~swift
import SwiftUI
import AppKit

@main
struct AppManagerApp: App {
    init() {
        // 从命令行（swift run）启动时，确保窗口能正常获得焦点
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
~~~

- [ ] **Step 2: 占位主视图**

~~~swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("AppManager")
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
~~~

- [ ] **Step 3: 运行验证**

Run: swift run（窗口应弹出显示 AppManager；Ctrl+C 退出）
Expected: 应用窗口出现且获得焦点

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: minimal runnable SwiftUI app window"
~~~

---

## P1：模型、存储与一键启动（MVP）

### Task 1.1: 数据模型

**Files:**
- Create: Sources/AppManager/Models/ServiceKind.swift
- Create: Sources/AppManager/Models/ManagedService.swift
- Create: Sources/AppManager/Models/ServiceStatus.swift
- Test: Tests/AppManagerTests/ManagedServiceTests.swift

- [ ] **Step 1: 写失败测试（Codable 往返）**

~~~swift
import Testing
import Foundation
@testable import AppManager

struct ManagedServiceTests {
    @Test func codableRoundtrip() throws {
        let service = ManagedService(
            name: "本地博客", category: "Web", kind: .url,
            url: "http://localhost:4000", checkURL: "http://localhost:4000/health"
        )
        let data = try JSONEncoder().encode(service)
        let decoded = try JSONDecoder().decode(ManagedService.self, from: data)
        #expect(decoded == service)
    }

    @Test func defaultsApplied() {
        let service = ManagedService(name: "测试", category: "默认")
        #expect(service.kind == .command)
        #expect(service.icon == "square.stack.3d.up")
        #expect(service.id != UUID())
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test
Expected: 编译失败（类型不存在）

- [ ] **Step 3: 实现模型**

~~~swift
// ServiceKind.swift
import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case app      // 打开 macOS 应用
    case url      // 打开网页
    case command  // 执行命令

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: "应用"
        case .url: "网页"
        case .command: "命令"
        }
    }
}
~~~

~~~swift
// ManagedService.swift
import Foundation

struct ManagedService: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var category: String
    var icon: String = "square.stack.3d.up"
    var kind: ServiceKind = .command
    var appPath: String?       // kind == .app
    var url: String?           // kind == .url
    var command: String?       // kind == .command 的主启动命令
    var checkURL: String?      // 健康检查地址（可选）
    var statusCommand: String? // 查询状态命令（可选，exit 0 = 正常）
    var startCommand: String?
    var stopCommand: String?
    var restartCommand: String?
    var pidPattern: String?    // 资源监控用进程名匹配（可选）
    var sortOrder: Int = 0
}
~~~

~~~swift
// ServiceStatus.swift
import Foundation

enum ServiceStatus: Equatable, Sendable {
    case unknown
    case healthy(latencyMs: Int)
    case down(reason: String)

    var label: String {
        switch self {
        case .unknown: "未知"
        case .healthy(let ms): "正常 · \(ms)ms"
        case .down(let reason): "离线 · \(reason)"
        }
    }

    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }
}
~~~

- [ ] **Step 4: 运行确认通过**

Run: swift test
Expected: ManagedServiceTests 全绿

- [ ] **Step 5: 提交**

~~~bash
git add Sources/AppManager/Models Tests/AppManagerTests
git commit -m "feat: service data models with codable roundtrip tests"
~~~

### Task 1.2: JSON 存储 ServiceStore

**Files:**
- Create: Sources/AppManager/Storage/ServiceStore.swift
- Test: Tests/AppManagerTests/ServiceStoreTests.swift

- [ ] **Step 1: 写失败测试（临时目录 + CRUD）**

~~~swift
import Testing
import Foundation
@testable import AppManager

struct ServiceStoreTests {
    @Test func loadMissingFileIsEmpty() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        #expect(store.services.isEmpty)
    }

    @Test func addPersistsAndReloads() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "Docker", category: "容器", kind: .command, command: "docker ps"))

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.count == 1)
        #expect(reloaded.services[0].name == "Docker")
    }

    @Test func deleteRemoves() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        let s = ManagedService(name: "A", category: "C")
        try store.add(s)
        try store.delete(s)

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.isEmpty)
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test
Expected: 编译失败（ServiceStore 不存在）

- [ ] **Step 3: 实现 ServiceStore**

~~~swift
import Foundation
import Observation

@Observable
final class ServiceStore {
    private(set) var services: [ManagedService] = []
    let fileURL: URL

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppManager", isDirectory: true)
        return base.appendingPathComponent("services.json")
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        try? load()
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        services = try JSONDecoder().decode([ManagedService].self, from: data)
    }

    func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(services)
        try data.write(to: fileURL, options: .atomic)
    }

    func add(_ service: ManagedService) throws {
        services.append(service)
        try save()
    }

    func update(_ service: ManagedService) throws {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx] = service
        try save()
    }

    func delete(_ service: ManagedService) throws {
        services.removeAll { $0.id == service.id }
        try save()
    }

    var categories: [String] {
        var seen = Set<String>()
        return services.map(\.category).filter { seen.insert($0).inserted }.sorted()
    }
}
~~~

- [ ] **Step 4: 运行确认通过**

Run: swift test
Expected: ServiceStoreTests 全绿

- [ ] **Step 5: 提交**

~~~bash
git add Sources/AppManager/Storage Tests/AppManagerTests
git commit -m "feat: JSON-backed ServiceStore with CRUD tests"
~~~

### Task 1.3: 命令执行器 CommandRunner

**Files:**
- Create: Sources/AppManager/Services/CommandRunner.swift
- Test: Tests/AppManagerTests/CommandRunnerTests.swift

- [ ] **Step 1: 写失败测试**

~~~swift
import Testing
@testable import AppManager

struct CommandRunnerTests {
    @Test func runsEcho() async throws {
        let result = try await CommandRunner.run("echo hello")
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test func capturesNonZeroExit() async throws {
        let result = try await CommandRunner.run("exit 3")
        #expect(result.exitCode == 3)
    }

    @Test func capturesStderr() async throws {
        let result = try await CommandRunner.run("echo oops >&2; exit 1")
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("oops"))
    }

    @Test func timesOut() async throws {
        let result = try await CommandRunner.run("sleep 5", timeout: 1)
        #expect(result.isTimedOut)
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test
Expected: 编译失败

- [ ] **Step 3: 实现 CommandRunner**

~~~swift
import Foundation

struct CommandResult: Equatable, Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var isTimedOut = false
}

enum CommandRunnerError: Error, LocalizedError {
    case timeout(seconds: TimeInterval)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds): "命令执行超时（\(Int(seconds)) 秒）"
        case .launchFailed(let msg): "无法启动命令：\(msg)"
        }
    }
}

enum CommandRunner {
    /// 确保 brew 命令可被发现（Intel Mac 上 /usr/local/bin 也保留）
    static let defaultPath = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    static func run(
        _ command: String,
        environment: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = defaultPath
        env.merge(environment) { _, new in new }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        // 进程运行期间并行读管道，避免管道缓冲死锁
        async let outData = outPipe.fileHandleForReading.readToEnd()
        async let errData = errPipe.fileHandleForReading.readToEnd()

        var didTimeout = false
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    process.terminate()
                    throw CommandRunnerError.timeout(seconds: timeout)
                }
                group.addTask {
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        process.terminationHandler = { _ in cont.resume() }
                    }
                }
                try await group.next()
                group.cancelAll()
            }
        } catch CommandRunnerError.timeout {
            didTimeout = true
        }

        let stdout = String(data: (try? await outData) ?? Data(), encoding: .utf8) ?? ""
        let stderr = String(data: (try? await errData) ?? Data(), encoding: .utf8) ?? ""
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            isTimedOut: didTimeout
        )
    }
}
~~~

- [ ] **Step 4: 运行确认通过**

Run: swift test
Expected: CommandRunnerTests 全绿（timeout 测试约 1 秒）

- [ ] **Step 5: 提交**

~~~bash
git add Sources/AppManager/Services Tests/AppManagerTests
git commit -m "feat: async Process command runner with tests"
~~~

### Task 1.4: 启动编排 ServiceController

**Files:**
- Create: Sources/AppManager/Services/ServiceController.swift
- Test: Tests/AppManagerTests/ServiceControllerTests.swift

- [ ] **Step 1: 写失败测试（注入假 runner）**

~~~swift
import Testing
import Foundation
@testable import AppManager

struct ServiceControllerTests {
    @Test func launchesURLViaOpen() async throws {
        var ran: [String] = []
        let controller = ServiceController { cmd in
            ran.append(cmd)
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let service = ManagedService(name: "博客", category: "Web", kind: .url, url: "http://localhost:4000")
        _ = try await controller.launch(service)
        #expect(ran.first?.contains("http://localhost:4000") == true)
    }

    @Test func launchesCommand() async throws {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "", stderr: "") }
        let service = ManagedService(name: "Redis", category: "DB", kind: .command, command: "redis-cli ping")
        let result = try await controller.launch(service)
        #expect(result.exitCode == 0)
    }

    @Test func statusCommandHealthyWhenExitZero() async throws {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "running", stderr: "") }
        let service = ManagedService(name: "Nginx", category: "Web", statusCommand: "pgrep nginx")
        let status = try await controller.status(service)
        #expect(status.isHealthy)
    }

    @Test func startPrefersStartCommand() async throws {
        var ran: [String] = []
        let controller = ServiceController { cmd in
            ran.append(cmd)
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let service = ManagedService(name: "X", category: "C", command: "echo default", startCommand: "echo start")
        _ = try await controller.start(service)
        #expect(ran == ["echo start"])
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test
Expected: 编译失败

- [ ] **Step 3: 实现 ServiceController**

~~~swift
import AppKit
import Foundation

struct ServiceController {
    /// 注入式执行器：测试时替换为假实现
    let runner: (String) async throws -> CommandResult

    init(runner: @escaping (String) async throws -> CommandResult = { try await CommandRunner.run($0) }) {
        self.runner = runner
    }

    /// 一键启动：按类型分发
    func launch(_ service: ManagedService) async throws -> CommandResult {
        switch service.kind {
        case .app:
            guard let path = service.appPath, !path.isEmpty else {
                throw CommandRunnerError.launchFailed("未设置应用路径")
            }
            let url = URL(fileURLWithPath: path)
            let config = NSWorkspace.OpenConfiguration()
            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            return CommandResult(exitCode: app != nil ? 0 : 1, stdout: "已启动 \(service.name)", stderr: "")
        case .url:
            guard let url = service.url, !url.isEmpty else {
                throw CommandRunnerError.launchFailed("未设置网址")
            }
            return try await runner("open \"\(url)\"")
        case .command:
            guard let command = service.command, !command.isEmpty else {
                throw CommandRunnerError.launchFailed("未设置命令")
            }
            return try await runner(command)
        }
    }

    func start(_ service: ManagedService) async throws -> CommandResult {
        try await runner(service.startCommand ?? service.command ?? "")
    }

    func stop(_ service: ManagedService) async throws -> CommandResult {
        try await runner(service.stopCommand ?? "")
    }

    func restart(_ service: ManagedService) async throws -> CommandResult {
        try await runner(service.restartCommand ?? "")
    }

    func status(_ service: ManagedService) async throws -> ServiceStatus {
        guard let cmd = service.statusCommand, !cmd.isEmpty else { return .unknown }
        let result = try await runner(cmd)
        return result.exitCode == 0 ? .healthy(latencyMs: 0) : .down(reason: "进程未运行")
    }
}
~~~

- [ ] **Step 4: 运行确认通过**

Run: swift test
Expected: ServiceControllerTests 全绿

- [ ] **Step 5: 提交**

~~~bash
git add Sources/AppManager/Services Tests/AppManagerTests
git commit -m "feat: launch/start/stop/restart orchestration with injected runner"
~~~

### Task 1.5: 主界面（分类侧栏 + 列表 + 新增/编辑 + 一键启动）

**Files:**
- Create: Sources/AppManager/Views/ContentView.swift（重写占位）
- Create: Sources/AppManager/Views/ServiceListView.swift
- Create: Sources/AppManager/Views/ServiceRowView.swift
- Create: Sources/AppManager/Views/EditServiceView.swift
- Modify: Sources/AppManager/AppManagerApp.swift（注入 store）

- [ ] **Step 1: App 入口注入 store**

~~~swift
@main
struct AppManagerApp: App {
    @State private var store: ServiceStore

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        _store = State(initialValue: ServiceStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
~~~

- [ ] **Step 2: ContentView（分类侧栏 + 搜索 + 工具栏）**

~~~swift
import SwiftUI

struct ContentView: View {
    @Environment(ServiceStore.self) private var store
    @State private var selectedCategory: String? = "全部"
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingService: ManagedService?

    private var filteredServices: [ManagedService] {
        store.services
            .filter { selectedCategory == nil || selectedCategory == "全部" || $0.category == selectedCategory }
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.category.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Text("全部").tag(String?.some("全部"))
                ForEach(store.categories, id: \.self) { category in
                    Text(category).tag(String?.some(category))
                }
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } detail: {
            ServiceListView(services: filteredServices) { service in
                editingService = service
            } onDelete: { service in
                try? store.delete(service)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索服务…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("添加服务", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditServiceView(service: nil) { service in
                try? store.add(service)
            }
        }
        .sheet(item: $editingService) { service in
            EditServiceView(service: service) { updated in
                try? store.update(updated)
            }
        }
    }
}
~~~

- [ ] **Step 3: ServiceListView**

~~~swift
import SwiftUI

struct ServiceListView: View {
    let services: [ManagedService]
    let onEdit: (ManagedService) -> Void
    let onDelete: (ManagedService) -> Void

    var body: some View {
        List(services) { service in
            ServiceRowView(service: service)
                .contextMenu {
                    Button("编辑…") { onEdit(service) }
                    Button("删除", role: .destructive) { onDelete(service) }
                }
        }
        .overlay {
            if services.isEmpty {
                ContentUnavailableView(
                    "暂无服务",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("点右上角 + 添加一个服务")
                )
            }
        }
    }
}
~~~

- [ ] **Step 4: ServiceRowView（图标 + 名称 + 分类 + 启动按钮）**

~~~swift
import SwiftUI

struct ServiceRowView: View {
    let service: ManagedService
    @State private var isLaunching = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: service.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                Text(service.kind.displayName + (service.category.isEmpty ? "" : " · \(service.category)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isLaunching = true
                Task {
                    defer { isLaunching = false }
                    let controller = ServiceController()
                    _ = try? await controller.launch(service)
                }
            } label: {
                if isLaunching {
                    ProgressView().controlSize(.small)
                } else {
                    Label("启动", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
~~~

- [ ] **Step 5: EditServiceView（按类型显示不同字段的表单）**

~~~swift
import SwiftUI

struct EditServiceView: View {
    @Environment(\.dismiss) private var dismiss
    let service: ManagedService?
    let onSave: (ManagedService) -> Void

    @State private var name: String
    @State private var category: String
    @State private var icon: String
    @State private var kind: ServiceKind
    @State private var appPath: String
    @State private var url: String
    @State private var command: String
    @State private var checkURL: String
    @State private var statusCommand: String
    @State private var startCommand: String
    @State private var stopCommand: String
    @State private var restartCommand: String
    @State private var pidPattern: String

    init(service: ManagedService?, onSave: @escaping (ManagedService) -> Void) {
        self.service = service
        self.onSave = onSave
        _name = State(initialValue: service?.name ?? "")
        _category = State(initialValue: service?.category ?? "")
        _icon = State(initialValue: service?.icon ?? "square.stack.3d.up")
        _kind = State(initialValue: service?.kind ?? .command)
        _appPath = State(initialValue: service?.appPath ?? "")
        _url = State(initialValue: service?.url ?? "")
        _command = State(initialValue: service?.command ?? "")
        _checkURL = State(initialValue: service?.checkURL ?? "")
        _statusCommand = State(initialValue: service?.statusCommand ?? "")
        _startCommand = State(initialValue: service?.startCommand ?? "")
        _stopCommand = State(initialValue: service?.stopCommand ?? "")
        _restartCommand = State(initialValue: service?.restartCommand ?? "")
        _pidPattern = State(initialValue: service?.pidPattern ?? "")
    }

    var body: some View {
        Form {
            TextField("名称", text: $name)
            TextField("分类", text: $category)

            Picker("类型", selection: $kind) {
                ForEach(ServiceKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.segmented)

            switch kind {
            case .app:
                TextField("应用路径（如 /Applications/Safari.app）", text: $appPath)
            case .url:
                TextField("网址（如 http://localhost:4000）", text: $url)
            case .command:
                TextField("启动命令（如 brew services start redis）", text: $command)
            }

            Section("监控与状态（可选）") {
                TextField("健康检查地址", text: $checkURL, prompt: Text("http://localhost:4000/health"))
                TextField("状态命令", text: $statusCommand, prompt: Text("pgrep -f my-service"))
                TextField("进程名匹配（资源监控）", text: $pidPattern, prompt: Text("redis-server"))
            }

            Section("控制命令（可选，P3 起生效）") {
                TextField("启动", text: $startCommand)
                TextField("停止", text: $stopCommand)
                TextField("重启", text: $restartCommand)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(service == nil ? "添加服务" : "编辑服务")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(buildService())
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(width: 480)
    }

    private func buildService() -> ManagedService {
        ManagedService(
            id: service?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.trimmingCharacters(in: .whitespaces),
            icon: icon,
            kind: kind,
            appPath: kind == .app ? appPath : nil,
            url: kind == .url ? url : nil,
            command: kind == .command ? command : nil,
            checkURL: checkURL.isEmpty ? nil : checkURL,
            statusCommand: statusCommand.isEmpty ? nil : statusCommand,
            startCommand: startCommand.isEmpty ? nil : startCommand,
            stopCommand: stopCommand.isEmpty ? nil : stopCommand,
            restartCommand: restartCommand.isEmpty ? nil : restartCommand,
            pidPattern: pidPattern.isEmpty ? nil : pidPattern,
            sortOrder: service?.sortOrder ?? 0
        )
    }
}
~~~

- [ ] **Step 6: 构建 + 手工验收**

Run: swift build，再 swift run
手工检查：
1. 添加一个 kind = url 的服务（如 http://localhost:8080），保存后出现在列表
2. 点击"启动"，默认浏览器打开对应网址
3. 添加一个 kind = command 的服务（如 echo hello），启动按钮可执行
4. 侧栏分类切换与搜索过滤生效
5. 重启应用后服务清单仍在（JSON 已持久化）

- [ ] **Step 7: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: main UI with categories, CRUD forms and one-click launch"
~~~

---

## P2：状态监控

### Task 2.1: HealthChecker

**Files:**
- Create: Sources/AppManager/Services/HealthChecker.swift
- Test: Tests/AppManagerTests/HealthCheckerTests.swift

- [ ] **Step 1: 写失败测试**

~~~swift
import Testing
@testable import AppManager

struct HealthCheckerTests {
    @Test func invalidURLIsDown() async {
        let status = await HealthChecker.check(urlString: "not a url")
        if case .healthy = status { Issue.record("无效 URL 不应健康") }
    }

    @Test func unreachableHostIsDown() async {
        let status = await HealthChecker.check(urlString: "http://127.0.0.1:1/", timeout: 2)
        if case .healthy = status { Issue.record("不可达端口不应健康") }
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test
Expected: 编译失败

- [ ] **Step 3: 实现**

~~~swift
import Foundation

enum HealthChecker {
    static func check(urlString: String, timeout: TimeInterval = 5) async -> ServiceStatus {
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            return .down(reason: "URL 无效")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .down(reason: "非 HTTP 响应")
            }
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return (200..<400).contains(http.statusCode)
                ? .healthy(latencyMs: latency)
                : .down(reason: "HTTP \(http.statusCode)")
        } catch {
            return .down(reason: error.localizedDescription)
        }
    }
}
~~~

- [ ] **Step 4: 运行确认通过**

Run: swift test
Expected: HealthCheckerTests 全绿

- [ ] **Step 5: 提交**

~~~bash
git add Sources/AppManager/Services Tests/AppManagerTests
git commit -m "feat: URL health checker with tests"
~~~

### Task 2.2: 轮询调度 DashboardViewModel

**Files:**
- Create: Sources/AppManager/Services/DashboardViewModel.swift

- [ ] **Step 1: 实现**

~~~swift
import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var statuses: [UUID: ServiceStatus] = [:]
    var resources: [UUID: ProcessSample] = [:]
    private var monitorTask: Task<Void, Never>?
    private(set) var isMonitoring = false

    /// 启动定时轮询：健康检查 10 秒/次，资源采样 15 秒/次
    func start(store: ServiceStore) {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(store: store)
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    private func refresh(store: ServiceStore) async {
        let services = store.services
        await withTaskGroup(of: Void.self) { group in
            for service in services {
                group.addTask {
                    await self.checkOne(service)
                }
            }
            group.addTask {
                await self.sampleResources(matching: services)
            }
        }
    }

    private func checkOne(_ service: ManagedService) async {
        guard let url = service.checkURL else { return }
        let status = await HealthChecker.check(urlString: url)
        statuses[service.id] = status
    }

    private func sampleResources(matching services: [ManagedService]) async {
        let patterns = services.compactMap(\.pidPattern)
        guard !patterns.isEmpty,
              let samples = try? await ResourceMonitor.sample() else { return }
        for service in services {
            guard let pattern = service.pidPattern else { continue }
            let best = samples
                .filter { $0.command.localizedCaseInsensitiveContains(pattern) }
                .max(by: { $0.cpu < $1.cpu })
            resources[service.id] = best
        }
    }
}
~~~

- [ ] **Step 2: 构建**

Run: swift build
Expected: 编译通过

- [ ] **Step 3: 提交**

~~~bash
git add Sources/AppManager/Services
git commit -m "feat: periodic dashboard refresh loop"
~~~

### Task 2.3: 界面状态显示

**Files:**
- Modify: Sources/AppManager/Views/ServiceRowView.swift
- Modify: Sources/AppManager/Views/ContentView.swift
- Modify: Sources/AppManager/AppManagerApp.swift

- [ ] **Step 1: 注入 viewModel 并启动轮询**

App 入口加 @State private var viewModel = DashboardViewModel()，ContentView().environment(store).environment(viewModel)。

ContentView 加：

~~~swift
@Environment(DashboardViewModel.self) private var viewModel
// ...
.task {
    viewModel.start(store: store)
}
.onDisappear {
    viewModel.stop()
}
~~~

- [ ] **Step 2: 行内状态圆点 + 延迟**

ServiceRowView 加 @Environment(DashboardViewModel.self) private var viewModel，图标旁显示：

~~~swift
Circle()
    .fill(statusColor)
    .frame(width: 8, height: 8)

private var status: ServiceStatus {
    viewModel.statuses[service.id] ?? .unknown
}

private var statusColor: Color {
    switch status {
    case .healthy: .green
    case .down: .red
    case .unknown: .gray
    }
}
~~~

并在名称下方第二行显示 status.label（如"正常 · 23ms"）。

- [ ] **Step 3: 构建 + 手工验收**

Run: swift run
手工检查：添加一个带 checkURL 的服务（如 http://localhost:8080，先 python3 -m http.server 8080 启动它），10 秒内列表应显示绿点与延迟；停掉该服务后变红点。

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: live health status indicators in service rows"
~~~

---

## P3：服务控制（启停/重启/状态）

### Task 3.1: 控制命令接线

**Files:**
- Modify: Sources/AppManager/Views/ServiceRowView.swift

- [ ] **Step 1: 行内加启停/重启/状态按钮组**

~~~swift
private func controlButton(_ title: String, systemImage: String,
                           action: @escaping () async throws -> CommandResult) -> some View {
    Button {
        Task {
            let result = (try? await action()) ?? CommandResult(exitCode: -1, stdout: "", stderr: "执行失败")
            output = result
            showOutput = true
        }
    } label: {
        Label(title, systemImage: systemImage)
    }
    .controlSize(.small)
}

// 在行内（启动按钮旁）：
HStack(spacing: 6) {
    if service.stopCommand != nil { controlButton("停止", systemImage: "stop.fill") { try await controller.stop(service) } }
    if service.restartCommand != nil { controlButton("重启", systemImage: "arrow.clockwise") { try await controller.restart(service) } }
    Button {
        Task {
            let status = (try? await controller.status(service)) ?? .unknown
            viewModel.statuses[service.id] = status
        }
    } label: { Label("状态", systemImage: "stethoscope") }
    .controlSize(.small)
}
~~~

（controller 为 @State private var controller = ServiceController()；output / showOutput 为行内状态，供 CommandOutputView 弹出。）

- [ ] **Step 2: CommandOutputView（输出面板）**

~~~swift
import SwiftUI

struct CommandOutputView: View {
    let result: CommandResult
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.exitCode == 0 ? "完成" : "失败（exit \(result.exitCode)）")
                    .font(.headline)
                    .foregroundStyle(result.exitCode == 0 ? .green : .red)
                if result.isTimedOut { Text("超时").foregroundStyle(.orange) }
                Spacer()
            }
            ScrollView {
                Text(result.stdout + result.stderr)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 160, maxHeight: 300)
        }
        .padding()
        .frame(width: 560)
    }
}
~~~

在 ServiceRowView 用 .sheet(isPresented: $showOutput) { CommandOutputView(result: output) } 弹出。

- [ ] **Step 3: 构建 + 手工验收**

Run: swift run
手工检查：添加一个 Homebrew 服务（如 brew services list 中存在的），配置 start/stop 命令（brew services start xxx / brew services stop xxx），点击停止后健康检查变红、点击启动后变绿。

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager/Views
git commit -m "feat: service control buttons with command output panel"
~~~

---

## P4：自定义命令模板

### Task 4.1: 占位符替换

**Files:**
- Create: Sources/AppManager/Services/Placeholder.swift
- Test: Tests/AppManagerTests/PlaceholderTests.swift

- [ ] **Step 1: 写失败测试**

~~~swift
import Testing
@testable import AppManager

struct PlaceholderTests {
    @Test func substitutesVariables() {
        let result = Placeholder.substitute("docker run -p {port}:80 {image}", values: ["port": "8080", "image": "nginx"])
        #expect(result == "docker run -p 8080:80 nginx")
    }

    @Test func leavesUnknownPlaceholders() {
        let result = Placeholder.substitute("echo {name}", values: [:])
        #expect(result == "echo {name}")
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test

- [ ] **Step 3: 实现**

~~~swift
import Foundation

enum Placeholder {
    /// 将 {key} 形式的占位符替换为 values 中的值；未提供的保留原样
    static func substitute(_ template: String, values: [String: String]) -> String {
        values.reduce(template) { partial, kv in
            partial.replacingOccurrences(of: "{\(kv.key)}", with: kv.value)
        }
    }
}
~~~

- [ ] **Step 4: 运行确认通过 + 提交**

~~~bash
git add Sources/AppManager/Services Tests/AppManagerTests
git commit -m "feat: command template placeholder substitution"
~~~

### Task 4.2: 命令模板编辑与运行

**Files:**
- Modify: Sources/AppManager/Views/EditServiceView.swift
- Modify: Sources/AppManager/Services/ServiceController.swift

- [ ] **Step 1: 模型扩展**

ManagedService 增加字段 var variables: [String: String] = [:]（模板变量默认值），EditServiceView 增加"变量"编辑区：文本区按行 key=value 解析。

- [ ] **Step 2: 启动时应用占位符**

ServiceController.launch 的 command 分支改为：

~~~swift
let resolved = Placeholder.substitute(command, values: service.variables)
return try await runner(resolved)
~~~

- [ ] **Step 3: 手工验收**

Run: swift run
手工检查：添加命令 docker run -p {port}:80 nginx，变量 port=8081，启动后 docker ps 能看到 8081 端口映射。

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: customizable command templates with variables"
~~~

---

## P5：资源查看

### Task 5.1: ResourceMonitor

**Files:**
- Create: Sources/AppManager/Services/ResourceMonitor.swift
- Test: Tests/AppManagerTests/ResourceMonitorTests.swift

- [ ] **Step 1: 写失败测试（固定样本解析）**

~~~swift
import Testing
@testable import AppManager

struct ResourceMonitorTests {
    @Test func parsesSample() {
        let raw = """
123   1.2   0.5 /usr/bin/redis-server
456  12.3   4.5 /usr/bin/python3 http.server
"""
        let samples = ResourceMonitor.parse(raw)
        #expect(samples.count == 2)
        #expect(samples[0] == ProcessSample(pid: 123, cpu: 1.2, mem: 0.5, command: "/usr/bin/redis-server"))
        #expect(samples[1].cpu == 12.3)
    }

    @Test func ignoresMalformedLines() {
        let samples = ResourceMonitor.parse("not a number line\n789  0.1  0.2 cmd")
        #expect(samples.count == 1)
        #expect(samples[0].pid == 789)
    }
}
~~~

- [ ] **Step 2: 运行确认失败**

Run: swift test

- [ ] **Step 3: 实现**

~~~swift
import Foundation

struct ProcessSample: Equatable, Sendable {
    var pid: Int
    var cpu: Double
    var mem: Double
    var command: String
}

enum ResourceMonitor {
    static func sample() async throws -> [ProcessSample] {
        let result = try await CommandRunner.run("ps -axo pid=,pcpu=,pmem=,comm=", timeout: 10)
        return parse(result.stdout)
    }

    static func parse(_ raw: String) -> [ProcessSample] {
        raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else { return nil }
            let command = parts[3...].joined(separator: " ")
            return ProcessSample(pid: pid, cpu: cpu, mem: mem, command: command)
        }
    }
}
~~~

- [ ] **Step 4: 运行确认通过 + 提交**

~~~bash
git add Sources/AppManager/Services Tests/AppManagerTests
git commit -m "feat: ps-based resource monitor"
~~~

### Task 5.2: 详情页展示资源

**Files:**
- Create: Sources/AppManager/Views/ServiceDetailView.swift
- Modify: Sources/AppManager/Views/ServiceListView.swift（行可点击打开详情）

- [ ] **Step 1: 详情页（双击行或选中打开）**

展示：名称/分类/类型/命令字段 + viewModel.resources[service.id] 的 CPU/内存进度条（ProgressView(value:)）+ 最近状态。

- [ ] **Step 2: 构建 + 手工验收**

Run: swift run
手工检查：给某个运行中的服务（如 Node 进程）配 pidPattern，详情页显示 CPU/内存百分比并随轮询刷新。

- [ ] **Step 3: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: service detail view with live resource usage"
~~~

---

## P6：打磨（菜单栏、通知、搜索、打包）

### Task 6.1: 菜单栏常驻 + .app 打包脚本

**Files:**
- Create: scripts/bundle-app.sh
- Modify: Sources/AppManager/AppManagerApp.swift（MenuBarExtra 场景）

- [ ] **Step 1: 打包脚本**

~~~bash
#!/usr/bin/env bash
# 用法: ./scripts/bundle-app.sh   —— 将 .build 里的可执行文件打包成 AppManager.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/AppManager.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/AppManager "$APP/Contents/MacOS/AppManager"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AppManager</string>
    <key>CFBundleIdentifier</key><string>local.appmanager</string>
    <key>CFBundleName</key><string>AppManager</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"  # ad-hoc 签名
echo "✅ 打包完成: $APP"
~~~

执行 chmod +x scripts/bundle-app.sh 并运行，双击 dist/AppManager.app 应能打开。

- [ ] **Step 2: MenuBarExtra 场景（可选常驻）**

在 App body 的 WindowGroup 之外追加：

~~~swift
MenuBarExtra("AppManager", systemImage: "square.stack.3d.up") {
    MenuBarView()
        .environment(store)
        .environment(viewModel)
}
.menuBarExtraStyle(.window)
~~~

（说明：菜单栏场景需要 .app bundle 才能稳定显示——这正是 Step 1 打包脚本的意义；直接 swift run 时菜单栏可能不出现，属预期。）

- [ ] **Step 3: 提交**

~~~bash
git add scripts Sources/AppManager
git commit -m "feat: menu bar extra and .app bundling script"
~~~

### Task 6.2: 服务离线通知

**Files:**
- Create: Sources/AppManager/Services/Notifier.swift

- [ ] **Step 1: 实现通知助手**

~~~swift
import UserNotifications

enum Notifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
~~~

- [ ] **Step 2: DashboardViewModel 在服务从健康变离线时发通知（去重：记录 lastDown 集合）**

在 checkOne 中：若新状态为 down 且之前为 healthy，调用 await Notifier.notify(title: service.name, body: "服务已离线")。

- [ ] **Step 3: 手工验收**

通过 .app 运行（bundle 后的应用，CFBundleIdentifier 存在时通知才可靠），停掉一个被监控服务，等轮询发现后应弹出系统通知。

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: offline notifications for monitored services"
~~~

### Task 6.3: 设置页与收尾

**Files:**
- Create: Sources/AppManager/Views/SettingsView.swift
- Modify: Sources/AppManager/AppManagerApp.swift（Settings 场景）

- [ ] **Step 1: 设置页**

轮询间隔（秒，默认 10）、健康检查超时（默认 5）、通知开关；保存到 UserDefaults。

- [ ] **Step 2: README**

创建 README.md：项目简介、swift run 运行方式、./scripts/bundle-app.sh 打包方式、数据文件位置（Application Support/AppManager/services.json）。

- [ ] **Step 3: 最终构建 + 全量测试 + 提交**

~~~bash
swift build && swift test
git add -A
git commit -m "chore: settings page, README and final polish"
~~~

---

## 风险与备注

1. **CLI 启动窗口**：swift run 时通过 setActivationPolicy(.regular) + activate 保证窗口前置（P0 已处理）。
2. **管道死锁**：CommandRunner 用 async let 并行读取 stdout/stderr，避免进程写满管道缓冲后阻塞（P1 已处理）。
3. **MenuBarExtra 依赖 .app bundle**：直接 swift run 菜单栏可能不显示，用 scripts/bundle-app.sh 打包后运行（P6 已处理）。
4. **通知依赖 bundle identifier**：离线通知在 swift run 下可能无效，需打包后运行。
5. **无沙盒**：应用需要执行任意命令，不开 App Sandbox，仅个人本机使用。
6. **数据位置**：services.json 存于 ~/Library/Application Support/AppManager/，备份即拷贝该文件。