import Foundation

enum ServiceStatus: Equatable, Sendable {
    case unknown
    case running          // 进程/应用运行中（非网络检测）
    case healthy(latencyMs: Int) // 网络健康检查通过
    case down(reason: String)
    case stopped          // 未运行（应用未启动 / 服务已停止，非故障）

    var label: String {
        switch self {
        case .unknown: "未知"
        case .running: "运行中"
        case .healthy(let ms): "正常 · \(ms)ms"
        case .down(let reason): "离线 · \(reason)"
        case .stopped: "未运行"
        }
    }

    var isHealthy: Bool {
        switch self {
        case .running, .healthy: return true
        default: return false
        }
    }
}
