import Foundation

struct ManagedService: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var category: String
    var icon: String = "square.stack.3d.up"
    var kind: ServiceKind = .command
    var appPath: String?       // kind == .app
    var url: String?           // kind == .url
    var command: String?       // kind == .command 的主启动命令
    var checkURL: String?      // 健康检查地址（可选）
    var statusCommand: String? // 查询状态命令（可选，exit 0 = 正常）
    var startCommand: String?
    var stopCommand: String?
    var restartCommand: String?
    var pidPattern: String?    // 资源监控用进程名匹配（可选）
    var sortOrder: Int = 0
    var variables: [String: String] = [:] // 命令模板变量（P4）
}
