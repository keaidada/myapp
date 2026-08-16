import Foundation

struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
}

enum AppScanner {
    /// 默认扫描目录（可注入便于测试）
    static let defaultSearchDirs = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
        "/System/Applications"
    ]

    static func scan(dirs: [String] = defaultSearchDirs) -> [InstalledApp] {
        var result: [InstalledApp] = []
        var seen = Set<String>()
        for dir in dirs {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let fullPath = (dir as NSString).appendingPathComponent(entry)
                let name = (entry as NSString).deletingPathExtension
                guard seen.insert(name).inserted else { continue } // 同名去重
                result.append(InstalledApp(name: name, path: fullPath))
            }
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
