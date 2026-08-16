import Testing
import Foundation
@testable import AppManager

struct BatchOperationsTests {
    private func fakeController(exitCode: Int32) -> ServiceController {
        ServiceController { _ in
            CommandResult(exitCode: exitCode, stdout: "", stderr: "")
        }
    }

    @Test func launchAllCountsResults() async {
        let services = [
            ManagedService(name: "A", category: "C", kind: .url, url: "http://a"),
            ManagedService(name: "B", category: "C", kind: .url, url: "http://b")
        ]
        let summary = await BatchOperations.launchAll(services, controller: fakeController(exitCode: 0))
        #expect(summary.total == 2)
        #expect(summary.ok == 2)
        #expect(summary.failed == 0)
    }

    @Test func launchAllCountsFailures() async {
        let services = [
            ManagedService(name: "A", category: "C", kind: .url, url: "http://a"),
            ManagedService(name: "B", category: "C", kind: .url, url: "http://b")
        ]
        let summary = await BatchOperations.launchAll(services, controller: fakeController(exitCode: 1))
        #expect(summary.ok == 0)
        #expect(summary.failed == 2)
    }

    @Test func stopAllOnlyTargetsWithStopCommand() async {
        let services = [
            ManagedService(name: "有停止", category: "C", stopCommand: "echo stop"),
            ManagedService(name: "无停止", category: "C")
        ]
        let summary = await BatchOperations.stopAll(services, controller: fakeController(exitCode: 0))
        #expect(summary.total == 1)
        #expect(summary.ok == 1)
    }

    @Test func emptyReturnsZeroSummary() async {
        let summary = await BatchOperations.restartAll([], controller: fakeController(exitCode: 0))
        #expect(summary == BatchOperations.Summary())
    }

    @Test func summaryText() {
        let summary = BatchOperations.Summary(total: 3, ok: 2, failed: 1)
        #expect(summary.text == "完成 2/3，失败 1")
    }
}
