import AppKit
import ApplicationServices
import CoreGraphics

/// 一个菜单栏图标项（用 CGWindow 表示，原理同 Ice/Bartender）
struct MenuBarItemInfo: Identifiable {
    let windowID: CGWindowID
    let appName: String
    let ownerName: String?
    let title: String?
    let layer: Int
    /// 拥有该菜单栏图标的应用 PID（来自窗口 OwnerPID，精确）
    let ownerPID: pid_t
    /// 同一应用的所有菜单栏窗口ID（隐藏时全部处理，兼容微信多容器）
    var relatedWindowIDs: [CGWindowID] = []

    var id: String { "\(appName)" }
}

/// 菜单栏图标纳管：枚举当前菜单栏的图标项（CGWindow 层），控制显示/隐藏。
/// 原理与 Bartender / Ice 相同：用 CGWindowListCopyWindowInfo 遍历菜单栏窗口。
/// 隐藏通过 kAXHiddenAttribute 或窗口层级控制 —— 但 Ice 实际是用 CGWindow 做 move 隐藏，
/// 这里提供枚举 + 隐藏接口，隐藏依赖辅助功能授权。
enum MenuBarManager {
    // MARK: - 权限

    /// 是否已获得辅助功能授权（缓存，避免反复查询 + 写日志）
    private static var cachedTrusted: Bool?
    static var isTrusted: Bool {
        if let cached = cachedTrusted { return cached }
        let trusted = AXIsProcessTrusted()
        cachedTrusted = trusted
        debugLog("isTrusted -> \(trusted)")
        return trusted
    }

    /// 弹出系统授权提示（若未授权），并打开系统设置面板
    static func requestAccessibilityPermission() {
        cachedTrusted = nil
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 枚举（CGWindow 层）

    /// 枚举当前菜单栏的图标项：遍历所有窗口，筛选位于菜单栏区域（顶部、高约 33）的。
    /// 每个应用记一个代表窗口ID + 该应用的所有菜单栏窗口ID（隐藏时全部处理）。
    static func menuBarItems() -> [MenuBarItemInfo] {
        debugLog("menuBarItems() 调用, isTrusted=\(isTrusted)")
        var result: [MenuBarItemInfo] = []

        let allWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
            as? [[String: Any]] ?? []

        // 按 owner 聚合：owner -> 所有位于菜单栏的窗口ID
        var ownerWindowIDs: [String: [CGWindowID]] = [:]
        var ownerFirst: [String: MenuBarItemInfo] = [:]
        var ownerMeta: [String: (pid: pid_t, name: String)] = [:]

        for window in allWindows {
            let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
            guard let y = bounds["Y"] as? Double, let height = bounds["Height"] as? Double else { continue }
            guard y >= -1 && y < 40, height > 10 && height < 45 else { continue }

            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer == 0 else { continue } // 应用菜单栏图标在 layer 0

            let windowID = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
            let ownerPid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "?"
            let pidKey = "\(ownerPid)"

            ownerWindowIDs[pidKey, default: []].append(windowID)
            if ownerMeta[pidKey] == nil {
                let appName = owningAppName(pid: ownerPid, ownerName: ownerName)
                ownerMeta[pidKey] = (ownerPid, appName)
                ownerFirst[pidKey] = MenuBarItemInfo(
                    windowID: windowID,
                    appName: appName,
                    ownerName: ownerName,
                    title: window[kCGWindowName as String] as? String,
                    layer: layer,
                    ownerPID: ownerPid
                )
            }
        }

        // 用第一个窗口ID作为代表，其余窗口ID存进一个聚合集合供隐藏用
        for (pidKey, info) in ownerFirst {
            var item = info
            item.relatedWindowIDs = ownerWindowIDs[pidKey] ?? []
            result.append(item)
        }
        debugLog("枚举到 \(result.count) 个应用菜单栏项: \(result.map { "\($0.appName)(\($0.relatedWindowIDs.count)窗)" }.joined(separator: ", "))")
        return result
    }

    /// 根据 PID 找应用名（用 NSWorkspace，比 ownerName 更友好）
    private static func owningAppName(pid: pid_t, ownerName: String?) -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            return app.localizedName ?? app.bundleIdentifier ?? (ownerName ?? "未知应用")
        }
        return ownerName ?? "未知应用"
    }

    /// 按应用名归类（用于界面展示）
    static func groupedByApp(_ items: [MenuBarItemInfo]) -> [(name: String, pid: pid_t, items: [MenuBarItemInfo])] {
        let grouped = Dictionary(grouping: items) { $0.appName }
        return grouped.map { (name: $0.key, pid: 0, items: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 隐藏/显示某个菜单栏项：用公开 AX kAXHiddenAttribute（稳定、不崩溃）。
    /// 注意：对用全宽容器窗口承载 NSStatusItem 的应用（如微信/元宝）可能无法隐藏，
    /// 这是 macOS 的系统限制（Bartender 靠私有 API + 屏幕录制，但脆裂且随系统更新可能失效）。
    @discardableResult
    static func setHidden(_ item: MenuBarItemInfo, hidden: Bool) -> Bool {
        let ok = applyAXHidden(item, hidden: hidden)
        debugLog("setHidden \(item.appName) hidden=\(hidden) via AX -> \(ok ? "成功" : "失败(应用可能不响应)")")
        return ok
    }

    /// AX kAXHiddenAttribute 方式（标准 NSStatusItem）
    private static func applyAXHidden(_ item: MenuBarItemInfo, hidden: Bool) -> Bool {
        guard isTrusted else { return false }
        let pid = owningPid(for: item)
        guard pid > 0 else { return false }
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBarValue = copyAttribute(appElement, "AXMenuBar" as CFString) else { return false }
        let menuBar = menuBarValue as! AXUIElement
        guard let items = copyAttribute(menuBar, "AXMenuBarItems" as CFString) as? [AXUIElement], !items.isEmpty else { return false }
        var success = false
        for axItem in items {
            let result = AXUIElementSetAttributeValue(axItem, kAXHiddenAttribute as CFString, hidden as CFBoolean)
            if result == .success { success = true }
        }
        return success
    }

    /// 从应用名查 PID（用枚举时记录的真实 ownerPID，最精确）
    private static func owningPid(for item: MenuBarItemInfo) -> pid_t {
        if item.ownerPID > 0 { return item.ownerPID }
        return NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "") == item.appName || ($0.bundleIdentifier ?? "") == item.ownerName
        }?.processIdentifier ?? 0
    }

    // MARK: - AX 辅助

    private static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value
    }

    // MARK: - 调试日志

    private static func debugLog(_ message: String) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myapp", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("menubar-debug.log")
        // 限 200KB，超出则重写，避免无限增长
        if (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 200_000 {
            try? FileManager.default.removeItem(at: url)
        }
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url)
        }
    }
}
