import Testing
import Foundation
@testable import AppManager

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
}
