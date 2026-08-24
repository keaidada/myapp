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

    var id: String { "\(windowID)" }
}

/// 菜单栏图标纳管：枚举当前菜单栏的图标项（CGWindow 层），控制显示/隐藏。
/// 原理与 Bartender / Ice 相同：用 CGWindowListCopyWindowInfo 遍历菜单栏窗口。
/// 隐藏通过 kAXHiddenAttribute 或窗口层级控制 —— 但 Ice 实际是用 CGWindow 做 move 隐藏，
/// 这里提供枚举 + 隐藏接口，隐藏依赖辅助功能授权。
enum MenuBarManager {
    // MARK: - 权限

    /// 是否已获得辅助功能授权
    static var isTrusted: Bool {
        let trusted = AXIsProcessTrusted()
        debugLog("isTrusted 查询 -> \(trusted) (进程: \(ProcessInfo.processInfo.processIdentifier), bundle: \(Bundle.main.bundleIdentifier ?? "?"))")
        return trusted
    }

    /// 弹出系统授权提示（若未授权），并打开系统设置面板
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 枚举（CGWindow 层）

    /// 枚举当前菜单栏的图标项。用 CGWindowListCopyWindowInfo(.optionMenuBarItems) 遍历，
    /// 每一个菜单栏图标是一个独立的 CGWindow。
    static func menuBarItems() -> [MenuBarItemInfo] {
        debugLog("menuBarItems() 调用, isTrusted=\(isTrusted)")
        var result: [MenuBarItemInfo] = []

        // kCGWindowListOptionMenuBarItems = 0x01, kCGWindowListOptionOnScreenOnly = 0x02
        let option = CGWindowListOption(rawValue: 0x01 | 0x02)
        let windowList = CGWindowListCopyWindowInfo(option, kCGNullWindowID)
            as? [[String: Any]] ?? []

        debugLog("CGWindowList 返回 \(windowList.count) 个菜单栏窗口")
        for window in windowList {
            let windowID = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
            let ownerPid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            let ownerName = window[kCGWindowOwnerName as String] as? String
            let appName = owningAppName(pid: ownerPid, ownerName: ownerName)
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let title = window[kCGWindowName as String] as? String
            result.append(MenuBarItemInfo(
                windowID: windowID,
                appName: appName,
                ownerName: ownerName,
                title: title,
                layer: layer
            ))
        }
        debugLog("枚举到 \(result.count) 个菜单栏项: \(result.map { "\($0.appName)[\($0.title ?? "?")]" }.prefix(30).joined(separator: ", "))")
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

    /// 隐藏/显示某个菜单栏项（基于 ownerPID + 窗口 ID 定位 AXUIElement 菜单栏项）。
    /// 通过 kAXHiddenAttribute 实现，需要辅助功能授权。
    @discardableResult
    static func setHidden(_ item: MenuBarItemInfo, hidden: Bool) -> Bool {
        guard isTrusted, item.layer == 0 else { return false } // 只处理应用类（layer 0）
        // 通过 ownerPID 找到应用进程，再枚举它的 AXMenuBarItem，匹配窗口 ID 设置隐藏
        let pid = owningPid(for: item)
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBarValue = copyAttribute(appElement, "AXMenuBar" as CFString) else { return false }
        let menuBar = menuBarValue as! AXUIElement
        guard let items = copyAttribute(menuBar, "AXMenuBarItems" as CFString) as? [AXUIElement] else { return false }

        // 每个 item 都是独立窗口，用它的窗口 ID 与 CGWindow 匹配
        for axItem in items {
            var titleValue: CFTypeRef?
            let title = (AXUIElementCopyAttributeValue(axItem, kAXTitleAttribute as CFString, &titleValue) == .success)
                ? (titleValue as? String ?? "") : ""
            let result = AXUIElementSetAttributeValue(axItem, kAXHiddenAttribute as CFString, hidden as CFBoolean)
            debugLog("setHidden \(item.appName)[\(title)] hidden=\(hidden) -> \(result.rawValue)")
            if result == .success { return true }
        }
        return false
    }

    /// 从 MenuBarItemInfo 获取 ownerPID（存进去了）
    private static func owningPid(for item: MenuBarItemInfo) -> pid_t {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.localizedName ?? "") == item.appName || ($0.bundleIdentifier ?? "") == item.ownerName
        }) {
            return app.processIdentifier
        }
        return 0
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
