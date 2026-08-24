import Testing
import Foundation
@testable import myapp

struct ServiceStoreTests {
    @Test func loadMissingFileIsEmpty() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        #expect(store.services.isEmpty)
    }

    @Test func recordLaunchIncrementsAndPersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        let service = ManagedService(name: "Ollama", category: "AI")
        try store.add(service)

        store.recordLaunch(service.id)
        store.recordLaunch(service.id)
        #expect(store.services[0].launchCount == 2)
        #expect(store.services[0].lastLaunchedAt != nil)

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services[0].launchCount == 2)
    }

    @Test func hotServicesSortsByCountThenRecent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))

        let a = ManagedService(name: "A", category: "C")
        let b = ManagedService(name: "B", category: "C")
        let c = ManagedService(name: "C", category: "C")
        try store.add(a)
        try store.add(b)
        try store.add(c)

        store.recordLaunch(c.id)          // C: 1 次
        store.recordLaunch(a.id)
        store.recordLaunch(a.id)          // A: 2 次
        store.recordLaunch(b.id)          // B: 1 次（晚于 C）

        let hot = store.hotServices(limit: 10)
        #expect(hot.map(\.name) == ["A", "B", "C"])
    }

    @Test func hotServicesExcludesNeverLaunched() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))

        let a = ManagedService(name: "A", category: "C")
        let b = ManagedService(name: "B", category: "C")
        try store.add(a)
        try store.add(b)
        store.recordLaunch(a.id)

        let hot = store.hotServices(limit: 10)
        #expect(hot.map(\.name) == ["A"])
    }

    @Test func hotServicesRespectsLimit() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))

        for i in 0..<3 {
            let s = ManagedService(name: "S\(i)", category: "C")
            try store.add(s)
            store.recordLaunch(s.id)
        }
        #expect(store.hotServices(limit: 2).count == 2)
    }

    @Test func addPersistsAndReloads() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "Docker", category: "容器", kind: .command, command: "docker ps"))

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.count == 1)
        #expect(reloaded.services[0].name == "Docker")
    }

    @Test func updateReplaces() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        var s = ManagedService(name: "A", category: "C")
        try store.add(s)
        s.name = "B"
        try store.update(s)

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.count == 1)
        #expect(reloaded.services[0].name == "B")
    }

    @Test func deleteRemoves() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")

        let store = ServiceStore(fileURL: fileURL)
        let s = ManagedService(name: "A", category: "C")
        try store.add(s)
        try store.delete(s)

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.isEmpty)
    }

    @Test func categoriesAreSortedUnique() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        try store.add(ManagedService(name: "A", category: "Web"))
        try store.add(ManagedService(name: "B", category: "DB"))
        try store.add(ManagedService(name: "C", category: "Web"))
        #expect(store.categories == ["DB", "Web"])
    }

    @Test func moveReordersAndPersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)

        let a = ManagedService(name: "A", category: "C")
        let b = ManagedService(name: "B", category: "C")
        let c = ManagedService(name: "C", category: "C")
        try store.add(a)
        try store.add(b)
        try store.add(c)

        try store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(store.services.map(\.name) == ["C", "A", "B"])
        #expect(store.services.map(\.sortOrder) == [0, 1, 2])

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.map(\.name) == ["C", "A", "B"])
    }

    @Test func exportImportRoundtrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "A", category: "C"))
        try store.add(ManagedService(name: "B", category: "D", kind: .url, url: "http://x"))

        let data = try store.exportData()

        let other = ServiceStore(fileURL: fileURL)
        try other.importData(data)
        #expect(other.services.count == 2)
        #expect(other.services[0].name == "A")
        #expect(other.services[1].kind == .url)
        #expect(other.services[1].url == "http://x")
    }

    @Test func importReplacesExisting() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "旧", category: "C"))

        let data = try JSONEncoder().encode([ManagedService(name: "新", category: "C")])
        try store.importData(data)
        #expect(store.services.count == 1)
        #expect(store.services[0].name == "新")
    }

    @Test func addAllDeduplicatesByName() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "A", category: "C"))

        let added = try store.addAll([
            ManagedService(name: "A", category: "C"),
            ManagedService(name: "B", category: "C"),
            ManagedService(name: "C", category: "C")
        ])
        #expect(added == 2)
        #expect(store.services.count == 3)

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.count == 3)
    }

    @Test func addAllEmptyDoesNothing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        let added = try store.addAll([])
        #expect(added == 0)
        #expect(store.services.isEmpty)
    }

    @Test func deleteAllRemovesMultiple() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)

        let a = ManagedService(name: "A", category: "C")
        let b = ManagedService(name: "B", category: "C")
        let c = ManagedService(name: "C", category: "C")
        try store.add(a)
        try store.add(b)
        try store.add(c)

        let removed = try store.deleteAll([a.id, c.id])
        #expect(removed == 2)
        #expect(store.services.map(\.name) == ["B"])

        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services.map(\.name) == ["B"])
    }

    @Test func deleteAllUnknownIDsDoesNothing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        try store.add(ManagedService(name: "A", category: "C"))

        let removed = try store.deleteAll([UUID()])
        #expect(removed == 0)
        #expect(store.services.count == 1)
    }
}
