import Foundation

enum AutoRestartPolicy {
    /// 是否应对该服务执行自动唤醒：
    /// - 开关开启
    /// - 服务有健康检查地址（有明确的"应该在线"信号）
    /// - 当前状态为 down（网络故障/服务挂了）
    /// - 应用类不自动唤醒（打开应用是用户行为）
    static func shouldRestart(service: ManagedService, status: ServiceStatus, enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard service.kind != .app else { return false }
        guard service.checkURL != nil else { return false }
        guard let startCommand = service.startCommand ?? service.command,
              !startCommand.isEmpty else { return false }
        if case .down = status { return true }
        return false
    }
}
