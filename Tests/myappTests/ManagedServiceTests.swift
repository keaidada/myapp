import Testing
import Foundation
@testable import myapp

struct ManagedServiceTests {
    @Test func codableRoundtrip() throws {
        let service = ManagedService(
            name: "本地博客", category: "Web", kind: .url,
            url: "http://localhost:4000", checkURL: "http://localhost:4000/health"
        )
        let data = try JSONEncoder().encode(service)
        let decoded = try JSONDecoder().decode(ManagedService.self, from: data)
        #expect(decoded == service)
    }

    @Test func defaultsApplied() {
        let service = ManagedService(name: "测试", category: "默认")
        #expect(service.kind == .command)
        #expect(service.icon == "square.stack.3d.up")
        #expect(service.id != UUID())
    }

    @Test func decodesMissingOptionalFields() throws {
        let json = """
        {"name": "FlowScope 开发服务", "category": "开发", "kind": "command",
         "command": "dev-server.sh start", "checkURL": "http://127.0.0.1:3000/api/health"}
        """
        let service = try JSONDecoder().decode(ManagedService.self, from: Data(json.utf8))
        #expect(service.name == "FlowScope 开发服务")
        #expect(service.id != UUID())
        #expect(service.icon == "square.stack.3d.up")
        #expect(service.tags.isEmpty)
        #expect(service.sortOrder == 0)
        #expect(service.checkURL == "http://127.0.0.1:3000/api/health")
    }

    @Test func decodesArrayWithOneMissingField() throws {
        let json = """
        [
          {"id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", "name": "A", "category": "C"},
          {"name": "B", "category": "C"}
        ]
        """
        let services = try JSONDecoder().decode([ManagedService].self, from: Data(json.utf8))
        #expect(services.count == 2)
        #expect(services[1].id != UUID())
    }

    @Test func sendableConformance() {
        let service = ManagedService(name: "A", category: "B")
        let box = SendableBox(value: service)
        #expect(box.value.name == "A")
    }
}

struct SendableBox<T: Sendable> {
    let value: T
}
