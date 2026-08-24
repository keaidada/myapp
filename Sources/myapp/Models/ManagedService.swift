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
    var variables: [String: String] = [:] // 命令模板变量
    var appIconData: Data?     // 真实应用图标 PNG（kind == .app 时可选）
    var tags: [String] = []    // 标签（用于分类整理）
    var launchCount = 0        // 启动次数（最近热度统计）
    var lastLaunchedAt: Date?  // 最近一次启动时间
    var aliases: [String] = [] // 搜索别名（如英文名对应的中文名）

    /// 容错解码：缺失字段一律用默认值，避免历史/手工 JSON 缺字段导致整体加载失败
    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        icon: String = "square.stack.3d.up",
        kind: ServiceKind = .command,
        appPath: String? = nil,
        url: String? = nil,
        command: String? = nil,
        checkURL: String? = nil,
        statusCommand: String? = nil,
        startCommand: String? = nil,
        stopCommand: String? = nil,
        restartCommand: String? = nil,
        pidPattern: String? = nil,
        sortOrder: Int = 0,
        variables: [String: String] = [:],
        appIconData: Data? = nil,
        tags: [String] = [],
        launchCount: Int = 0,
        lastLaunchedAt: Date? = nil,
        aliases: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.kind = kind
        self.appPath = appPath
        self.url = url
        self.command = command
        self.checkURL = checkURL
        self.statusCommand = statusCommand
        self.startCommand = startCommand
        self.stopCommand = stopCommand
        self.restartCommand = restartCommand
        self.pidPattern = pidPattern
        self.sortOrder = sortOrder
        self.variables = variables
        self.appIconData = appIconData
        self.tags = tags
        self.launchCount = launchCount
        self.lastLaunchedAt = lastLaunchedAt
        self.aliases = aliases
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, icon, kind, appPath, url, command
        case checkURL, statusCommand, startCommand, stopCommand, restartCommand
        case pidPattern, sortOrder, variables, appIconData, tags
        case launchCount, lastLaunchedAt, aliases
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "square.stack.3d.up"
        kind = try c.decodeIfPresent(ServiceKind.self, forKey: .kind) ?? .command
        appPath = try c.decodeIfPresent(String.self, forKey: .appPath)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        command = try c.decodeIfPresent(String.self, forKey: .command)
        checkURL = try c.decodeIfPresent(String.self, forKey: .checkURL)
        statusCommand = try c.decodeIfPresent(String.self, forKey: .statusCommand)
        startCommand = try c.decodeIfPresent(String.self, forKey: .startCommand)
        stopCommand = try c.decodeIfPresent(String.self, forKey: .stopCommand)
        restartCommand = try c.decodeIfPresent(String.self, forKey: .restartCommand)
        pidPattern = try c.decodeIfPresent(String.self, forKey: .pidPattern)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        variables = try c.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        appIconData = try c.decodeIfPresent(Data.self, forKey: .appIconData)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        launchCount = try c.decodeIfPresent(Int.self, forKey: .launchCount) ?? 0
        lastLaunchedAt = try c.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }
}
