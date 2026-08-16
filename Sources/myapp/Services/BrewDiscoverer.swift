import Foundation

struct BrewService: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var status: String
    var isRunning: Bool

    /// 一键添加时自动生成的服务配置（命令自动填好）
    func makeService() -> ManagedService {
        ManagedService(
            name: name,
            category: "Homebrew",
            icon: "server.rack",
            kind: .command,
            command: "brew services start \(name)",
            statusCommand: "brew services list | grep '^\(name)' | grep -q started",
            startCommand: "brew services start \(name)",
            stopCommand: "brew services stop \(name)",
            restartCommand: "brew services restart \(name)",
            pidPattern: name
        )
    }
}

enum BrewDiscoverer {
    /// 运行 brew services list 发现本机 Homebrew 服务
    static func discover() async -> [BrewService] {
        guard let result = try? await CommandRunner.run("brew services list", timeout: 15) else {
            return []
        }
        return parse(result.stdout)
    }

    static func parse(_ output: String) -> [BrewService] {
        var services: [BrewService] = []
        let lines = output.split(separator: "\n")
        for line in lines.dropFirst() { // 跳过表头
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, parts[0] != "Name" else { continue }
            let name = String(parts[0])
            let status = String(parts[1])
            services.append(BrewService(name: name, status: status, isRunning: status == "started"))
        }
        return services
    }
}
