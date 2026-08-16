import Foundation

struct ProcessSample: Equatable, Sendable {
    var pid: Int
    var cpu: Double
    var mem: Double
    var command: String
}

enum ResourceMonitor {
    static func sample() async throws -> [ProcessSample] {
        // command= 给出完整路径+参数，便于 pidPattern 匹配
        let result = try await CommandRunner.run("ps -axo pid=,pcpu=,pmem=,command=", timeout: 10)
        return parse(result.stdout)
    }

    static func parse(_ raw: String) -> [ProcessSample] {
        raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else { return nil }
            let command = parts[3...].joined(separator: " ")
            return ProcessSample(pid: pid, cpu: cpu, mem: mem, command: command)
        }
    }
}
