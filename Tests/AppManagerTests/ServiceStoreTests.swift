import Testing
import Foundation
@testable import AppManager

struct ServiceStoreTests {
    @Test func loadMissingFileIsEmpty() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        #expect(store.services.isEmpty)
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
}
