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

    @Test func appLaunchRequiresPath() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "", stderr: "") }
        let service = ManagedService(name: "X", category: "C", kind: .app)
        do {
            _ = try await controller.launch(service)
            Issue.record("应当抛出错误")
        } catch {
            // 预期行为
        }
    }
}
