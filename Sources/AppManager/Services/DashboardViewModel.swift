import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var statuses: [UUID: ServiceStatus] = [:]
    var resources: [UUID: ProcessSample] = [:]
    var pollInterval: TimeInterval = 10
    var notifyOnDown = true
    private var monitorTask: Task<Void, Never>?
    private var lastDown: Set<UUID> = []
    private(set) var isMonitoring = false

    /// 启动定时轮询：健康检查 + 资源采样，统一每个 pollInterval 一轮
    func start(store: ServiceStore) {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(store: store)
                try? await Task.sleep(for: .seconds(self?.pollInterval ?? 10))
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
        // 支持 {key} 模板变量
        let resolved = Placeholder.substitute(url, values: service.variables)
        let status = await HealthChecker.check(urlString: resolved)
        statuses[service.id] = status

        if notifyOnDown {
            switch status {
            case .down:
                if !lastDown.contains(service.id) {
                    lastDown.insert(service.id)
                    await Notifier.notify(title: service.name, body: "服务已离线")
                }
            default:
                lastDown.remove(service.id)
            }
        }
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

    /// 是否有服务离线（菜单栏汇总用）
    var hasDownService: Bool {
        statuses.values.contains { status in
            if case .down = status { return true }
            return false
        }
    }

    /// 离线服务数
    var downCount: Int {
        statuses.values.reduce(0) { count, status in
            if case .down = status { return count + 1 }
            return count
        }
    }
}
