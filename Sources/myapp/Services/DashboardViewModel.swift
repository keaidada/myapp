import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class DashboardViewModel {
    var statuses: [UUID: ServiceStatus] = [:]
    var resources: [UUID: ProcessSample] = [:]
    var pollInterval: TimeInterval = 10
    var notifyOnDown = true
    var autoRestartEnabled = false
    var autoRestartMaxAttempts = 3
    var autoRestartInterval: TimeInterval = 30
    var commandLog: CommandLog?
    private var monitorTask: Task<Void, Never>?
    private var lastDown: Set<UUID> = []
    private var restartAttempts: [UUID: Int] = [:]
    private var bundleIDCache: [String: String] = [:]
    private var didFirstRefresh = false
    private let controller = ServiceController()
    private(set) var isMonitoring = false

    /// 第一次轮询检测完成后的回调（用于初始化排序快照，让"运行在上"生效）
    var onFirstRefresh: (() -> Void)?

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

    func refreshNow(store: ServiceStore) async {
        await refresh(store: store)
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
        if !didFirstRefresh {
            didFirstRefresh = true
            onFirstRefresh?()
        }
    }

    private func checkOne(_ service: ManagedService) async {
        // 应用类：直接检测进程是否在运行
        if service.kind == .app {
            statuses[service.id] = appIsRunning(service) ? .running : .stopped
            return
        }

        // 有健康检查 URL：网络检测
        if let url = service.checkURL {
            let resolved = Placeholder.substitute(url, values: service.variables)
            let status = await HealthChecker.check(urlString: resolved)
            statuses[service.id] = status
            notifyIfDown(service, status)
            handleAutoRestart(service, status)
            return
        }

        // 有状态命令：命令检测
        if service.statusCommand != nil {
            let result = (try? await controller.runStatus(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "状态查询失败")
            let status: ServiceStatus = result.exitCode == 0 ? .running : .stopped
            statuses[service.id] = status
            return
        }

        // 都没有：保持未知
    }

    // ── 自动唤醒 ──

    private func handleAutoRestart(_ service: ManagedService, _ status: ServiceStatus) {
        // 恢复健康：清零重试计数
        if case .healthy = status {
            restartAttempts.removeValue(forKey: service.id)
            return
        }
        guard AutoRestartPolicy.shouldRestart(service: service, status: status, enabled: autoRestartEnabled) else {
            return
        }
        let attempts = restartAttempts[service.id] ?? 0
        guard attempts < autoRestartMaxAttempts else { return }
        restartAttempts[service.id] = attempts + 1
        let interval = autoRestartInterval
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard let self, !Task.isCancelled else { return }
            await self.performRestart(service, attempt: attempts + 1)
        }
    }

    private func performRestart(_ service: ManagedService, attempt: Int) async {
        let startCmd = service.startCommand ?? service.command ?? ""
        guard !startCmd.isEmpty else { return }
        let result = (try? await controller.start(service))
            ?? CommandResult(exitCode: -1, stdout: "", stderr: "自动唤醒失败")
        commandLog?.record(
            serviceName: service.name,
            command: "自动唤醒(尝试\(attempt)): \(startCmd)",
            result: result
        )
    }

    // ── 其它 ──

    private func appIsRunning(_ service: ManagedService) -> Bool {
        guard let path = service.appPath else { return false }
        let bid = bundleIDCache[path] ?? bundleIdentifier(for: path)
        bundleIDCache[path] = bid
        if let bid {
            return NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bid && !$0.isTerminated
            }
        }
        return false
    }

    private func bundleIdentifier(for appPath: String) -> String? {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any],
              let bid = plist["CFBundleIdentifier"] as? String else { return nil }
        return bid
    }

    private func notifyIfDown(_ service: ManagedService, _ status: ServiceStatus) {
        guard notifyOnDown else { return }
        switch status {
        case .down:
            if !lastDown.contains(service.id) {
                lastDown.insert(service.id)
                Task { await Notifier.notify(title: service.name, body: "服务已离线") }
            }
        default:
            lastDown.remove(service.id)
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

    /// 是否有服务处于故障（离线）状态
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
