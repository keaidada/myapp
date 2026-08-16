import Testing
import Foundation
@testable import myapp

struct ServiceTemplateTests {
    @Test func catalogNotEmpty() {
        #expect(!ServiceTemplates.all.isEmpty)
        #expect(!ServiceTemplates.categories.isEmpty)
    }

    @Test func makeServiceFillsFields() {
        let template = ServiceTemplate(
            name: "redis", category: "Homebrew", icon: "server.rack", kind: .command,
            command: "brew services start redis",
            checkURL: "http://localhost:6379",
            statusCommand: "brew services list | grep redis | grep -q started",
            startCommand: "brew services start redis",
            stopCommand: "brew services stop redis",
            pidPattern: "redis-server"
        )
        let service = template.makeService()
        #expect(service.name == "redis")
        #expect(service.kind == .command)
        #expect(service.command == "brew services start redis")
        #expect(service.checkURL == "http://localhost:6379")
        #expect(service.stopCommand != nil)
        #expect(service.pidPattern == "redis-server")
        #expect(service.variables.isEmpty)
    }

    @Test func commandTemplatesHaveCommands() {
        for template in ServiceTemplates.all where template.kind == .command {
            #expect(template.command != nil && !template.command!.isEmpty,
                    "命令类模板必须带命令: \(template.name)")
            // start 命令可为空：ServiceController.start 会回退到 command
        }
    }

    @Test func appTemplatesHavePaths() {
        for template in ServiceTemplates.all where template.kind == .app {
            #expect(template.appPath != nil && !template.appPath!.isEmpty,
                    "应用类模板必须带路径: \(template.name)")
        }
    }

    @Test func namesUnique() {
        let names = ServiceTemplates.all.map(\.name)
        #expect(Set(names).count == names.count, "模板名不应重复")
    }
}
