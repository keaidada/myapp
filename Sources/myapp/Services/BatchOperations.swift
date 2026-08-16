import Foundation

@MainActor
enum BatchOperations {
    struct Summary: Equatable, Sendable {
        var total = 0
        var ok = 0
        var failed = 0

        var text: String {
            "完成 \(ok)/\(total)，失败 \(failed)"
        }
    }

    static func launchAll(
        _ services: [ManagedService],
        controller: ServiceController = ServiceController()
    ) async -> Summary {
        await summarize(services) { service in
            let result = (try? await controller.launch(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "启动失败")
            return result.exitCode == 0
        }
    }

    static func stopAll(
        _ services: [ManagedService],
        controller: ServiceController = ServiceController()
    ) async -> Summary {
        let targets = services.filter { $0.stopCommand != nil }
        return await summarize(targets) { service in
            let result = (try? await controller.stop(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "停止失败")
            return result.exitCode == 0
        }
    }

    static func restartAll(
        _ services: [ManagedService],
        controller: ServiceController = ServiceController()
    ) async -> Summary {
        let targets = services.filter { $0.restartCommand != nil }
        return await summarize(targets) { service in
            let result = (try? await controller.restart(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "重启失败")
            return result.exitCode == 0
        }
    }

    private static func summarize(
        _ services: [ManagedService],
        operation: @escaping (ManagedService) async -> Bool
    ) async -> Summary {
        guard !services.isEmpty else { return Summary() }
        return await withTaskGroup(of: Bool.self) { group in
            for service in services {
                group.addTask {
                    await operation(service)
                }
            }
            var summary = Summary(total: services.count)
            for await ok in group {
                if ok { summary.ok += 1 } else { summary.failed += 1 }
            }
            return summary
        }
    }
}
