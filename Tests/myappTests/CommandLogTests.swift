import Testing
import Foundation
@testable import myapp

@MainActor
struct CommandLogTests {
    private func tempLog() throws -> CommandLog {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return CommandLog(fileURL: dir.appendingPathComponent("history.json"))
    }

    @Test func recordAddsToFront() throws {
        let log = try tempLog()
        log.record(serviceName: "A", command: "echo 1", result: CommandResult(exitCode: 0, stdout: "1", stderr: ""))
        log.record(serviceName: "B", command: "echo 2", result: CommandResult(exitCode: 1, stdout: "", stderr: "err"))
        #expect(log.entries.count == 2)
        #expect(log.entries[0].serviceName == "B")
        #expect(log.entries[0].succeeded == false)
        #expect(log.entries[1].serviceName == "A")
        #expect(log.entries[1].succeeded == true)
    }

    @Test func capsAt50() throws {
        let log = try tempLog()
        for i in 0..<60 {
            log.record(serviceName: "S\(i)", command: "echo", result: CommandResult(exitCode: 0, stdout: "", stderr: ""))
        }
        #expect(log.entries.count == 50)
        #expect(log.entries[0].serviceName == "S59")
    }

    @Test func persistsAndReloads() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("history.json")

        let log = CommandLog(fileURL: fileURL)
        log.record(serviceName: "X", command: "echo hi", result: CommandResult(exitCode: 0, stdout: "hi", stderr: ""))

        let reloaded = CommandLog(fileURL: fileURL)
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries[0].serviceName == "X")
        #expect(reloaded.entries[0].stdout == "hi")
    }

    @Test func clearEmpties() throws {
        let log = try tempLog()
        log.record(serviceName: "A", command: "echo", result: CommandResult(exitCode: 0, stdout: "", stderr: ""))
        log.clear()
        #expect(log.entries.isEmpty)
    }
}
