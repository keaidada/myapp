import Foundation

enum QuickLaunchMatcher {
    static func matches(_ service: ManagedService, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return service.name.localizedCaseInsensitiveContains(q)
            || service.aliases.contains { $0.localizedCaseInsensitiveContains(q) }
            || service.category.localizedCaseInsensitiveContains(q)
            || service.tags.contains { $0.localizedCaseInsensitiveContains(q) }
    }

    /// 排序：前缀匹配 > 名称包含 > 标签匹配 > 分类匹配，其余不返回
    static func ranked(_ services: [ManagedService], query: String, limit: Int = 15) -> [ManagedService] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            return Array(services.prefix(limit))
        }
        func score(_ s: ManagedService) -> Int {
            if s.name.lowercased().hasPrefix(q.lowercased()) { return 0 }
            if s.name.localizedCaseInsensitiveContains(q) { return 1 }
            if s.aliases.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return 1 }
            if s.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return 2 }
            if s.category.localizedCaseInsensitiveContains(q) { return 3 }
            return 4
        }
        return services
            .filter { matches($0, query: q) }
            .sorted {
                let a = score($0), b = score($1)
                if a != b { return a < b }
                return ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name)
            }
            .prefix(limit)
            .map { $0 }
    }
}
