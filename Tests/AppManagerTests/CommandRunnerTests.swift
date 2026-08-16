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

    @Test func brewAvailableInPath() async throws {
        let result = try await CommandRunner.run("command -v brew")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("brew"))
    }
}
