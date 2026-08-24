import Foundation

struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    /// 从 Info.plist 提取的显示名/本地化名（如 "TencentMeeting" → "腾讯会议"），用作搜索别名
    var aliases: [String] = []
}

enum AppScanner {
    /// 通过 LaunchServices 查询所有已注册应用（用 mdfind / Spotlight 的应用注册数据库），
    /// 返回完整 .app 路径。比物理遍历目录更全面 —— 能发现嵌套目录、~/Downloads、
    /// 以及不在标准 Applications 目录里的应用（如 Sublime Text、iOA）。
    /// @param query 注入查询命令便于测试；默认为 mdfind 应用查询
    static func scan(query: String = "kMDItemContentType == 'com.apple.application-bundle'") -> [InstalledApp] {
        guard let output = runMDFind(query) else { return [] }
        var result: [InstalledApp] = []
        var seen = Set<String>()
        for line in output {
            let path = line.trimmingCharacters(in: .whitespaces)
            guard path.hasSuffix(".app"), FileManager.default.fileExists(atPath: path) else { continue }
            let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            let normalizedPath = path.replacingOccurrences(of: "\u{200e}", with: "") // 去掉不可见字符
            if !seen.insert(name).inserted { continue } // 同名去重
            result.append(InstalledApp(name: name, path: normalizedPath, aliases: displayNames(for: normalizedPath)))
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// 执行 mdfind 查询，返回路径行（失败返回 nil）
    static func runMDFind(_ query: String) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [query]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .map(String.init)
        } catch {
            return nil
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
