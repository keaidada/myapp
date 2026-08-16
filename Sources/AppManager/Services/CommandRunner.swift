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
