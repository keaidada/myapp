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
        process.arguments = ["-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = defaultPath
        env.merge(environment) { _, newEnv in newEnv }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        // 先注册终止回调再启动，避免快退出的命令漏掉回调导致误判超时
        let exited = AsyncStream<Void>.makeStream()
        process.terminationHandler = { _ in
            exited.continuation.yield()
        }

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
                    _ = await exited.stream.first(where: { _ in true })
                }
                try await group.next()
                group.cancelAll()
            }
        } catch CommandRunnerError.timeout {
            didTimeout = true
            // SIGTERM 后必须等进程真正退出再读 terminationStatus，否则抛
            // NSInvalidArgumentException "task still running"。有界等待：
            // 2 秒内退出即继续；否则 SIGKILL 强杀。
            try? await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = await exited.stream.first(where: { _ in true })
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(2))
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
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
