import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var statuses: [UUID: ServiceStatus] = [:]
    var resources: [UUID: ProcessSample] = [:]
    private var monitorTask: Task<Void, Never>?
    private(set) var isMonitoring = false

    /// 启动定时轮询：健康检查 + 资源采样，统一每 10 秒一轮
    func start(store: ServiceStore) {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(store: store)
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    private func refresh(store: ServiceStore) async {
        let services = store.services
        await withTaskGroup(of: Void.self) { group in
            for service in services {
                group.addTask {
                    await self.checkOne(service)
                }
            }
            group.addTask {
                await self.sampleResources(matching: services)
            }
        }
    }

    private func checkOne(_ service: ManagedService) async {
        guard let url = service.checkURL else { return }
        let status = await HealthChecker.check(urlString: url)
        statuses[service.id] = status
    }

    private func sampleResources(matching services: [ManagedService]) async {
        let patterns = services.compactMap(\.pidPattern)
        guard !patterns.isEmpty,
              let samples = try? await ResourceMonitor.sample() else { return }
        for service in services {
            guard let pattern = service.pidPattern else { continue }
            let best = samples
                .filter { $0.command.localizedCaseInsensitiveContains(pattern) }
                .max(by: { $0.cpu < $1.cpu })
            resources[service.id] = best
        }
    }
}
