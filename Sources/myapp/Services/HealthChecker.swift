import Foundation

enum HealthChecker {
    static func check(urlString: String, timeout: TimeInterval = 5) async -> ServiceStatus {
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            return .down(reason: "URL 无效")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .down(reason: "非 HTTP 响应")
            }
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return (200..<400).contains(http.statusCode)
                ? .healthy(latencyMs: latency)
                : .down(reason: "HTTP \(http.statusCode)")
        } catch {
            return .down(reason: error.localizedDescription)
        }
    }
}
