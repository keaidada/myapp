import Foundation
import Observation

@Observable
final class ServiceStore {
    private(set) var services: [ManagedService] = []
    let fileURL: URL

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppManager", isDirectory: true)
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

    func update(_ service: ManagedService) throws {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx] = service
        try save()
    }

    func delete(_ service: ManagedService) throws {
        services.removeAll { $0.id == service.id }
        try save()
    }

    var categories: [String] {
        var seen = Set<String>()
        return services.map(\.category).filter { seen.insert($0).inserted }.sorted()
    }
}
