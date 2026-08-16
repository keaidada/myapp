import Testing
import Foundation
@testable import myapp

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

    @Test func statusCommandHealthyWhenExitZero() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "running", stderr: "") }
        let service = ManagedService(name: "Nginx", category: "Web", statusCommand: "pgrep nginx")
        let status = await controller.status(service)
        #expect(status.isHealthy)
    }

    @Test func statusCommandNonZeroIsStopped() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 1, stdout: "", stderr: "") }
        let service = ManagedService(name: "Nginx", category: "Web", statusCommand: "pgrep nginx")
        let status = await controller.status(service)
        #expect(status == .stopped)
    }

    @Test func noDetectionConfigIsUnknown() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "", stderr: "") }
        let service = ManagedService(name: "X", category: "C", kind: .command, command: "echo hi")
        let status = await controller.status(service)
        #expect(status == .unknown)
    }

    @Test func checkURLDownIsDown() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "", stderr: "") }
        let service = ManagedService(name: "X", category: "C", kind: .command, command: "echo", checkURL: "http://127.0.0.1:1/")
        let status = await controller.status(service)
        if case .healthy = status { Issue.record("不可达端口不应健康") }
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

    @Test func quitCommandServiceUsesStopCommand() async {
        var ran: [String] = []
        let controller = ServiceController { cmd in
            ran.append(cmd)
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        let service = ManagedService(name: "X", category: "C", kind: .command, command: "echo start", stopCommand: "echo stop")
        let result = await controller.quit(service)
        #expect(result.exitCode == 0)
        #expect(ran == ["echo stop"])
    }

    @Test func quitWithoutStopCommandFails() async {
        let controller = ServiceController { _ in CommandResult(exitCode: 0, stdout: "", stderr: "") }
        let service = ManagedService(name: "X", category: "C", kind: .command, command: "echo start")
        let result = await controller.quit(service)
        #expect(result.exitCode != 0)
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
