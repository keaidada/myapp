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

    /// 读取应用的 CFBundleName / CFBundleDisplayName，返回与包名不同的显示名（去重、去空白）。
    /// 优先从本地化文件（zh-Hans / zh-Hant / en 的 InfoPlist.strings）读取，
    /// 再兜底根 Info.plist —— 例如 WeChat 根 plist 只有 "WeChat"，中文名"微信"在 zh-Hans.lproj 里。
    static func displayNames(for appPath: String) -> [String] {
        var names: [String] = []
        let resourcesDir = (appPath as NSString)
            .appendingPathComponent("Contents/Resources")
        // 本地化显示名优先：简体中文 → 繁体中文 → 英文
        for locale in ["zh-Hans", "zh_CN", "zh-Hant", "zh_TW", "en"] {
            let stringsURL = URL(fileURLWithPath: resourcesDir)
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("InfoPlist.strings")
            guard let data = try? Data(contentsOf: stringsURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                    as? [String: Any] else { continue }
            for key in ["CFBundleName", "CFBundleDisplayName"] {
                if let value = plist[key] as? String {
                    collect(&names, value)
                }
            }
            break // 找到任一本地化文件即停止
        }
        // 兜底：根 Info.plist
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any] {
            for key in ["CFBundleName", "CFBundleDisplayName"] {
                if let value = plist[key] as? String {
                    collect(&names, value)
                }
            }
        }
        return names.sorted()
    }

    private static func collect(_ names: inout [String], _ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !names.contains(trimmed) {
            names.append(trimmed)
        }
    }
}
