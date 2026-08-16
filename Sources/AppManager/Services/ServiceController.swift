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

    func status(_ service: ManagedService) async throws -> ServiceStatus {
        guard let cmd = service.statusCommand, !cmd.isEmpty else { return .unknown }
        let result = try await runner(cmd)
        return result.exitCode == 0 ? .healthy(latencyMs: 0) : .down(reason: "进程未运行")
    }
}
