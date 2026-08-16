import Foundation

enum ServiceStatus: Equatable, Sendable {
    case unknown
    case healthy(latencyMs: Int)
    case down(reason: String)

    var label: String {
        switch self {
        case .unknown: "未知"
        case .healthy(let ms): "正常 · \(ms)ms"
        case .down(let reason): "离线 · \(reason)"
        }
    }

    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }
}
