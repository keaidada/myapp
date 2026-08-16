import Testing
import Foundation
@testable import myapp

struct ServiceTagTests {
    private func tempStore() throws -> (ServiceStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (ServiceStore(fileURL: dir.appendingPathComponent("services.json")), dir)
    }

    @Test func allTagsDeduplicatesAndSorts() throws {
        let (store, _) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["工作", "开发"]
        var b = ManagedService(name: "B", category: "C")
        b.tags = ["开发", "娱乐"]
        try store.add(a)
        try store.add(b)
        #expect(store.allTags == ["娱乐", "工作", "开发"])
    }

    @Test func addTagToSelection() throws {
        let (store, dir) = try tempStore()
        let a = ManagedService(name: "A", category: "C")
        let b = ManagedService(name: "B", category: "C")
        try store.add(a)
        try store.add(b)

        try store.addTag("工作", to: [a.id])
        #expect(store.services[0].tags == ["工作"])
        #expect(store.services[1].tags.isEmpty)

        try store.addTag("工作", to: [a.id])
        #expect(store.services[0].tags == ["工作"])

        let reloaded = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        #expect(reloaded.services[0].tags == ["工作"])
    }

    @Test func addTagTrimsEmpty() throws {
        let (store, _) = try tempStore()
        let a = ManagedService(name: "A", category: "C")
        try store.add(a)
        try store.addTag("   ", to: [a.id])
        try store.addTag("", to: [a.id])
        #expect(store.services[0].tags.isEmpty)
    }

    @Test func removeTagFromSelection() throws {
        let (store, _) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["工作", "开发"]
        try store.add(a)
        try store.removeTag("工作", from: [a.id])
        #expect(store.services[0].tags == ["开发"])
    }

    @Test func renameTagUpdatesAllServices() throws {
        let (store, _) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["工作", "开发"]
        var b = ManagedService(name: "B", category: "C")
        b.tags = ["工作"]
        try store.add(a)
        try store.add(b)

        try store.renameTag("工作", to: "职业")
        #expect(store.services[0].tags == ["职业", "开发"])
        #expect(store.services[1].tags == ["职业"])
        #expect(!store.allTags.contains("工作"))
        #expect(store.allTags.contains("职业"))
    }

    @Test func renameTagSameOrEmptyNoop() throws {
        let (store, _) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["工作"]
        try store.add(a)
        try store.renameTag("工作", to: "工作")
        try store.renameTag("工作", to: "  ")
        #expect(store.services[0].tags == ["工作"])
    }

    @Test func deleteTagRemovesEverywhere() throws {
        let (store, dir) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["工作", "开发"]
        var b = ManagedService(name: "B", category: "C")
        b.tags = ["工作"]
        try store.add(a)
        try store.add(b)

        try store.deleteTag("工作")
        #expect(store.services[0].tags == ["开发"])
        #expect(store.services[1].tags.isEmpty)
        #expect(!store.allTags.contains("工作"))

        let reloaded = ServiceStore(fileURL: dir.appendingPathComponent("services.json"))
        #expect(reloaded.services[1].tags.isEmpty)
    }

    @Test func countOfTag() throws {
        let (store, _) = try tempStore()
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["开发"]
        var b = ManagedService(name: "B", category: "C")
        b.tags = ["开发", "AI"]
        try store.add(a)
        try store.add(b)
        #expect(store.count(of: "开发") == 2)
        #expect(store.count(of: "AI") == 1)
        #expect(store.count(of: "不存在") == 0)
    }

    @Test func tagsCodableRoundtrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        var a = ManagedService(name: "A", category: "C")
        a.tags = ["标签1", "标签2"]
        try store.add(a)
        let reloaded = ServiceStore(fileURL: fileURL)
        #expect(reloaded.services[0].tags == ["标签1", "标签2"])
    }
}
