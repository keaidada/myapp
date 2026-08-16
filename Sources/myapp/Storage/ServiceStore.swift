import Foundation
import Observation

@Observable
final class ServiceStore {
    private(set) var services: [ManagedService] = []
    let fileURL: URL

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myapp", isDirectory: true)
        return base.appendingPathComponent("services.json")
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        try? load()
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        services = try JSONDecoder().decode([ManagedService].self, from: data)
    }

    func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(services)
        try data.write(to: fileURL, options: .atomic)
    }

    func add(_ service: ManagedService) throws {
        services.append(service)
        try save()
    }

    /// 批量添加：按名称去重，一次写盘
    @discardableResult
    func addAll(_ newServices: [ManagedService]) throws -> Int {
        let existing = Set(services.map(\.name))
        let toAdd = newServices.filter { !existing.contains($0.name) }
        guard !toAdd.isEmpty else { return 0 }
        services.append(contentsOf: toAdd)
        try save()
        return toAdd.count
    }

    func update(_ service: ManagedService) throws {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx] = service
        try save()
    }

    func delete(_ service: ManagedService) throws {
        services.removeAll { $0.id == service.id }
        try save()
    }

    /// 批量删除：一次写盘，返回删除数量
    @discardableResult
    func deleteAll(_ ids: Set<UUID>) throws -> Int {
        let before = services.count
        services.removeAll { ids.contains($0.id) }
        let removed = before - services.count
        if removed > 0 {
            try save()
        }
        return removed
    }

    /// 拖拽排序：移动后按新顺序重排 sortOrder
    func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        services.move(fromOffsets: source, toOffset: destination)
        for (i, _) in services.enumerated() {
            services[i].sortOrder = i
        }
        try save()
    }

    /// 导出为 JSON 数据
    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(services)
    }

    /// 从 JSON 文件导入（替换现有清单）
    func importFrom(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([ManagedService].self, from: data)
        services = decoded
        try save()
    }

    /// 从 JSON 数据导入（供测试与合并使用）
    func importData(_ data: Data) throws {
        services = try JSONDecoder().decode([ManagedService].self, from: data)
        try save()
    }

    var categories: [String] {
        var seen = Set<String>()
        return services.map(\.category).filter { seen.insert($0).inserted }.sorted()
    }
}
