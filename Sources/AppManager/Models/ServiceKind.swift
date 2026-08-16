import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case app      // 打开 macOS 应用
    case url      // 打开网页
    case command  // 执行命令

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: "应用"
        case .url: "网页"
        case .command: "命令"
        }
    }
}
