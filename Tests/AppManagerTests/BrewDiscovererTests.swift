import Testing
import Foundation
@testable import AppManager

struct BrewDiscovererTests {
    @Test func parsesBrewServicesList() {
        let output = """
        Name          Status  User File
        nginx         started liwei ~/Library/LaunchAgents/homebrew.mxcl.nginx.plist
        redis         started liwei ~/Library/LaunchAgents/homebrew.mxcl.redis.plist
        mysql         stopped
        postgresql@16 error   liwei ~/Library/LaunchAgents/homebrew.mxcl.postgresql@16.plist
        """
        let services = BrewDiscoverer.parse(output)
        #expect(services.count == 4)
        #expect(services[0].name == "nginx")
        #expect(services[0].isRunning)
        #expect(services[2].name == "mysql")
        #expect(!services[2].isRunning)
        #expect(services[3].status == "error")
    }

    @Test func emptyOutput() {
        #expect(BrewDiscoverer.parse("").isEmpty)
    }

    @Test func makeServiceFillsCommands() {
        let service = BrewService(name: "redis", status: "started", isRunning: true).makeService()
        #expect(service.category == "Homebrew")
        #expect(service.startCommand == "brew services start redis")
        #expect(service.stopCommand == "brew services stop redis")
        #expect(service.restartCommand == "brew services restart redis")
        #expect(service.statusCommand?.contains("redis") == true)
        #expect(service.kind == .command)
    }
}
