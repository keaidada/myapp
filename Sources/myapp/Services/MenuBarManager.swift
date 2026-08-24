import AppKit
import ApplicationServices

/// 一个菜单栏图标项（来自某个应用的 AXMenuBarItem）
struct MenuBarItemInfo: Identifiable {
    let pid: pid_t
    let appName: String
    let itemTitle: String
    /// 用于隐藏/显示操作的 AX 元素引用
    let element: AXUIElement

    var id: String { "\(pid)-\(itemTitle)-\(appName)" }
}

/// 菜单栏图标纳管：枚举所有应用的菜单栏项，控制显示/隐藏（kAXHiddenAttribute）。
/// 原理与 Bartender / 开源 Ice 相同，基于辅助功能（Accessibility）API。
/// 注意：隐藏只对"支持辅助功能读取"的应用生效，个别 app（如系统菜单栏）可能不可操作。
enum MenuBarManager {
    // MARK: - 权限

    /// 是否已获得辅助功能授权
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统授权提示（若未授权），并打开系统设置面板
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // 打开辅助功能设置页
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 枚举

    /// 扫描所有运行中应用，返回各自在菜单栏的图标项
    static func menuBarItems() -> [MenuBarItemInfo] {
        guard isTrusted else { return [] }
        var result: [MenuBarItemInfo] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else { continue }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let menuBarValue = copyAttribute(appElement, "AXMenuBar" as CFString) else { continue }
            let menuBar = menuBarValue as! AXUIElement
            guard let items = copyAttribute(menuBar, "AXMenuBarItems" as CFString) as? [AXUIElement] else { continue }
            for item in items {
                let title = (copyAttribute(item, kAXTitleAttribute as CFString) as? String) ?? ""
                let name = app.localizedName ?? app.bundleIdentifier ?? "未知应用"
                result.append(MenuBarItemInfo(pid: app.processIdentifier, appName: name, itemTitle: title, element: item))
            }
        }
        return result
    }

    /// 设置某个菜单栏项的显示/隐藏
    @discardableResult
    static func setHidden(_ item: MenuBarItemInfo, hidden: Bool) -> Bool {
        let result = AXUIElementSetAttributeValue(item.element, kAXHiddenAttribute as CFString, hidden as CFBoolean)
        return result == .success
    }

    /// 按应用名归类后的菜单栏项（用于界面展示：应用 → 它的图标）
    static func groupedByApp(_ items: [MenuBarItemInfo]) -> [(name: String, pid: pid_t, items: [MenuBarItemInfo])] {
        let grouped = Dictionary(grouping: items) { $0.appName }
        return grouped.map { (name: $0.key, pid: $0.value.first?.pid ?? 0, items: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - 工具

    private static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value
    }
}
