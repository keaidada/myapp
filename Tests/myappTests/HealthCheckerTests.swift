import Testing
import Foundation
@testable import myapp

struct HealthCheckerTests {
    @Test func invalidURLIsDown() async {
        let status = await HealthChecker.check(urlString: "not a url")
        if case .healthy = status { Issue.record("无效 URL 不应健康") }
    }

    @Test func unreachableHostIsDown() async {
        let status = await HealthChecker.check(urlString: "http://127.0.0.1:1/", timeout: 2)
        if case .healthy = status { Issue.record("不可达端口不应健康") }
    }

    @Test func missingSchemeIsDown() async {
        let status = await HealthChecker.check(urlString: "localhost:4000", timeout: 2)
        if case .healthy = status { Issue.record("缺少协议不应健康") }
    }

    @Test func healthyResponse() async throws {
        // 起一个临时 HTTP 服务器验证 200 判定
        let server = try PythonServer()
        let status = await HealthChecker.check(urlString: server.baseURL.absoluteString, timeout: 3)
        guard case .healthy(let ms) = status else {
            Issue.record("本地 200 响应应判为健康，实际: \(status)")
            return
        }
        #expect(ms >= 0)
        server.stop()
    }
}

/// 用 python3 -m http.server 起一个临时 HTTP 服务，用于健康检查的 200 判定测试
final class PythonServer {
    let baseURL: URL
    private var process: Process?

    init() throws {
        let port = 29000 + Int.random(in: 0..<500)
        baseURL = URL(string: "http://127.0.0.1:\(port)")!
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = ["-m", "http.server", String(port), "--bind", "127.0.0.1"]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try p.run()
        process = p
        Thread.sleep(forTimeInterval: 1.0) // 等待端口就绪
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
