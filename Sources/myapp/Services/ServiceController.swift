import AppKit
import Foundation

struct ServiceController {
    /// 注入式执行器：测试时替换为假实现
    let runner: (String) async throws -> CommandResult

    init(runner: @escaping (String) async throws -> CommandResult = { try await CommandRunner.run($0) }) {
        self.runner = runner
    }

    /// 直接执行任意命令（运行历史重跑用）
    func run(_ command: String) async throws -> CommandResult {
        try await runner(command)
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
            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                return CommandResult(exitCode: 0, stdout: "已启动 \(service.name)", stderr: "")
            } catch {
                return CommandResult(exitCode: 1, stdout: "", stderr: error.localizedDescription)
            }
        case .url:
            guard let url = service.url, !url.isEmpty else {
                throw CommandRunnerError.launchFailed("未设置网址")
            }
            return try await runner("open \"\(url)\"")
        case .command:
            guard let command = service.command, !command.isEmpty else {
                throw CommandRunnerError.launchFailed("未设置命令")
            }
            let resolved = Placeholder.substitute(command, values: service.variables)
            return try await runner(resolved)
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

    func runStatus(_ service: ManagedService) async throws -> CommandResult {
        guard let cmd = service.statusCommand, !cmd.isEmpty else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "未配置状态命令")
        }
        return try await runner(cmd)
    }

    /// 打开服务的界面/网页（服务运行中时由调用方控制可用性）
    func open(_ service: ManagedService) async throws -> CommandResult {
        // 优先明确 URL，其次健康检查地址（通常是 Web UI）
        if let urlString = service.url ?? service.checkURL {
            let resolved = Placeholder.substitute(urlString, values: service.variables)
            return try await runner("open \"\(resolved)\"")
        }
        // 应用类：运行中打开（聚焦）该应用
        if service.kind == .app, let path = service.appPath {
            let config = NSWorkspace.OpenConfiguration()
            _ = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
            return CommandResult(exitCode: 0, stdout: "已打开 \(service.name)", stderr: "")
        }
        return CommandResult(exitCode: -1, stdout: "", stderr: "没有可打开的地址（请配置 URL 或健康检查地址）")
    }

    /// 关闭服务：应用→优雅退出，Electron 等不响应退出事件时逐步升级到 TERM/KILL；
    /// 命令类→执行 stop 命令
    func quit(_ service: ManagedService) async -> CommandResult {
        if service.kind == .app {
            guard let path = service.appPath, !path.isEmpty,
                  let bid = bundleIdentifier(for: path) else {
                return CommandResult(exitCode: 1, stdout: "", stderr: "无法识别应用")
            }
            return await quitApp(appPath: path, bundleID: bid)
        }
        if let stop = service.stopCommand, !stop.isEmpty {
            return (try? await runner(stop))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "关闭命令执行失败")
        }
        return CommandResult(exitCode: -1, stdout: "", stderr: "未配置关闭命令")
    }

    /// 应用类关闭：terminate → 等待 → SIGTERM（按 PID 与路径）→ 等待 → SIGKILL
    /// 解决 Ollama 等 Electron 菜单栏应用拦截 terminate 退出的问题
    private func quitApp(appPath: String, bundleID: String, gracefulWait: Double = 1.5, killWait: Double = 1.0) async -> CommandResult {
        let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID && !$0.isTerminated
        })
        let pid = running?.processIdentifier

        // 第 1 步：优雅退出
        if let app = running {
            _ = app.terminate()
        }
        if await waitForExit(bundleID: bundleID, timeout: gracefulWait) {
            return CommandResult(exitCode: 0, stdout: "已关闭", stderr: "")
        }

        // 第 2 步：SIGTERM —— 对 Electron 应用有效
        if let pid {
            _ = try? await runner("kill -TERM \(pid)")
        }
        _ = try? await runner(pkillCommand(appPath: appPath, signal: "TERM"))
        if await waitForExit(bundleID: bundleID, timeout: killWait) {
            return CommandResult(exitCode: 0, stdout: "已强制关闭", stderr: "")
        }

        // 第 3 步：SIGKILL 兜底
        _ = try? await runner(pkillCommand(appPath: appPath, signal: "KILL"))
        let ok = await waitForExit(bundleID: bundleID, timeout: 0.5)
        return CommandResult(
            exitCode: ok ? 0 : 1,
            stdout: ok ? "已强制关闭" : "关闭失败",
            stderr: ok ? "" : "进程未响应终止请求"
        )
    }

    /// 生成按应用路径匹配主进程的 pkill 命令（提取为内部函数便于测试）
    func pkillCommand(appPath: String, signal: String) -> String {
        let escaped = appPath.replacingOccurrences(of: "'", with: "'\\''")
        return "pkill -\(signal) -f '\(escaped)/Contents/MacOS/'"
    }

    /// 轮询等待应用退出（bundle id 不再出现在运行列表）
    private func waitForExit(bundleID: String, timeout: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !NSWorkspace.shared.runningApplications.contains(where: {
                $0.bundleIdentifier == bundleID && !$0.isTerminated
            }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return !NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == bundleID && !$0.isTerminated
        })
    }

    /// 状态检测：按服务类型选择正确方式
    /// - app：进程是否在运行 → running / stopped
    /// - 有健康检查地址：网络检测 → healthy / down
    /// - 有状态命令：exit 0 → running，否则 stopped
    /// - 都没有：unknown（不误报离线）
    func status(_ service: ManagedService) async -> ServiceStatus {
        if service.kind == .app {
            return appIsRunning(service) ? .running : .stopped
        }
        if let url = service.checkURL {
            let resolved = Placeholder.substitute(url, values: service.variables)
            return await HealthChecker.check(urlString: resolved)
        }
        if service.statusCommand != nil {
            let result = (try? await runStatus(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "状态查询失败")
            return result.exitCode == 0 ? .running : .stopped
        }
        return .unknown
    }

    private func appIsRunning(_ service: ManagedService) -> Bool {
        guard let path = service.appPath,
              let bid = bundleIdentifier(for: path) else { return false }
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bid && !$0.isTerminated
        }
    }

    private func bundleIdentifier(for appPath: String) -> String? {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any],
              let bid = plist["CFBundleIdentifier"] as? String else { return nil }
        return bid
    }
}
