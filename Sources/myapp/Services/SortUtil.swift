import Foundation

enum SortUtil {
    /// 智能排序：运行中的排上面，同状态下按名称字母序
    /// statuses: 排序用状态快照（id → 是否运行），避免实时状态变化触发重排
    static func smartSorted(
        _ services: [ManagedService],
        runningSnapshot: [UUID: Bool]
    ) -> [ManagedService] {
        services.sorted { a, b in
            let aRun = runningSnapshot[a.id] ?? false
            let bRun = runningSnapshot[b.id] ?? false
            if aRun != bRun { return aRun }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// 手动排序：按 sortOrder + 名称
    static func manualSorted(_ services: [ManagedService]) -> [ManagedService] {
        services.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }
}
