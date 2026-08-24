import Foundation

struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    /// 从 Info.plist 提取的显示名/本地化名（如 "TencentMeeting" → "腾讯会议"），用作搜索别名
    var aliases: [String] = []
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
                result.append(InstalledApp(name: name, path: fullPath, aliases: displayNames(for: fullPath)))
            }
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// 读取应用的 CFBundleName / CFBundleDisplayName，返回与包名不同的显示名（去重、去空白）
    static func displayNames(for appPath: String) -> [String] {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any] else { return [] }
        var names: [String] = []
        for key in ["CFBundleName", "CFBundleDisplayName"] {
            guard let value = plist[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { names.append(trimmed) }
        }
        return Array(Set(names)).sorted()
    }
}
