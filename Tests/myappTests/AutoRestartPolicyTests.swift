import Testing
import Foundation
@testable import myapp

struct AutoRestartPolicyTests {
    private func commandService(checkURL: String? = "http://localhost:8080", startCommand: String? = "brew services start x") -> ManagedService {
        ManagedService(name: "X", category: "C", kind: .command, command: startCommand, checkURL: checkURL, startCommand: startCommand)
    }

    @Test func restartsWhenDownAndEnabled() {
        let service = commandService()
        #expect(AutoRestartPolicy.shouldRestart(service: service, status: .down(reason: "超时"), enabled: true))
    }

    @Test func noRestartWhenDisabled() {
        let service = commandService()
        #expect(!AutoRestartPolicy.shouldRestart(service: service, status: .down(reason: "超时"), enabled: false))
    }

    @Test func noRestartWhenHealthy() {
        let service = commandService()
        #expect(!AutoRestartPolicy.shouldRestart(service: service, status: .healthy(latencyMs: 5), enabled: true))
    }

    @Test func noRestartForApps() {
        let service = ManagedService(name: "Safari", category: "应用", kind: .app, appPath: "/Applications/Safari.app", checkURL: "http://x")
        #expect(!AutoRestartPolicy.shouldRestart(service: service, status: .down(reason: "x"), enabled: true))
    }

    @Test func noRestartWithoutCheckURL() {
        let service = commandService(checkURL: nil)
        #expect(!AutoRestartPolicy.shouldRestart(service: service, status: .down(reason: "x"), enabled: true))
    }

    @Test func noRestartWithoutStartCommand() {
        let service = ManagedService(name: "Y", category: "C", kind: .command, checkURL: "http://localhost:1")
        #expect(!AutoRestartPolicy.shouldRestart(service: service, status: .down(reason: "x"), enabled: true))
    }
}
