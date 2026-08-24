import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var menuBarGroups: [(name: String, pid: pid_t, items: [MenuBarItemInfo])] = []
    @State private var hiddenApps: Set<String> = []
    @State private var isTrusted = MenuBarManager.isTrusted
    @State private var refreshing = false

    /// 偏好存储：应用名 → 是否隐藏菜单栏图标（默认 false = 显示）
    private static let prefsKey = "menuBarHiddenApps"

    var body: some View {
        Form {
            Section("监控") {
                Stepper(
                    "轮询间隔：\(Int(viewModel.pollInterval)) 秒",
                    value: Binding(
                        get: { viewModel.pollInterval },
                        set: { viewModel.pollInterval = $0 }
                    ),
                    in: 5...120,
                    step: 5
                )
            }
            Section("通知") {
                Toggle(
                    "服务离线时通知",
                    isOn: Binding(
                        get: { viewModel.notifyOnDown },
                        set: { viewModel.notifyOnDown = $0 }
                    )
                )
            }
            Section("自动唤醒（服务挂了自动拉起）") {
                Toggle(
                    "启用自动唤醒",
                    isOn: Binding(
                        get: { viewModel.autoRestartEnabled },
                        set: { viewModel.autoRestartEnabled = $0 }
                    )
                )
                Stepper(
                    "最大重试次数：\(viewModel.autoRestartMaxAttempts)",
                    value: Binding(
                        get: { viewModel.autoRestartMaxAttempts },
                        set: { viewModel.autoRestartMaxAttempts = $0 }
                    ),
                    in: 1...10,
                    step: 1
                )
                .disabled(!viewModel.autoRestartEnabled)
                Stepper(
                    "重试间隔：\(Int(viewModel.autoRestartInterval)) 秒",
                    value: Binding(
                        get: { viewModel.autoRestartInterval },
                        set: { viewModel.autoRestartInterval = $0 }
                    ),
                    in: 10...300,
                    step: 10
                )
                .disabled(!viewModel.autoRestartEnabled)
                Text("仅对配置了健康检查地址的命令类服务生效；应用类不会自动启动")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("菜单栏图标") {
                if !isTrusted {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("需要辅助功能权限才能管理菜单栏图标", systemImage: "lock.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("授权步骤：")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("1. 点击下方按钮，打开系统设置")
                            Text("2. 在「隐私与安全性 → 辅助功能」中找到 myapp 并打开开关")
                            Text("3. 回到本窗口，会自动开始扫描（无需手动刷新）")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("授权辅助功能…") {
                            MenuBarManager.requestAccessibilityPermission()
                            // 轮询等待授权：授权成功立即刷新
                            Task {
                                while !MenuBarManager.isTrusted {
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                }
                                await MainActor.run {
                                    isTrusted = true
                                    refresh()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Button("仅保留系统图标") {
                            if menuBarGroups.isEmpty { refresh() }
                            applyDefaultRule()
                        }
                        .help("隐藏所有非系统应用（/System 或 Apple 出品）的菜单栏图标")
                        Spacer()
                        Button(refreshing ? "扫描中…" : "刷新") {
                            refresh()
                        }
                        .disabled(refreshing)
                    }
                    if menuBarGroups.isEmpty {
                        Text("未检测到菜单栏图标，或应用尚未显示图标")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(menuBarGroups, id: \.name) { group in
                            HStack {
                                appIcon(for: group)
                                Text(group.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(group.items.count) 个图标")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Toggle("", isOn: Binding(
                                    get: { !hiddenApps.contains(group.name) },
                                    set: { visible in
                                        setHidden(group.name, visible: visible)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                        Text("隐藏只是视觉收纳，应用仍正常运行；个别不配合的应用可能无法隐藏")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("数据") {
                LabeledContent("配置文件", value: ServiceStore.defaultFileURL.path)
                LabeledContent("版本", value: "myapp v0.9.1")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear {
            loadPrefs()
            refresh()
        }
    }

    // MARK: - 逻辑

    private func loadPrefs() {
        hiddenApps = Set(UserDefaults.standard.stringArray(forKey: Self.prefsKey) ?? [])
    }

    private func savePrefs() {
        UserDefaults.standard.set(Array(hiddenApps), forKey: Self.prefsKey)
        // 调试：确认持久化
        NSLog("menuBarHiddenApps saved: \(hiddenApps.sorted())")
        let log = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myapp/menubar-debug.log")
        let line = "\(Date()) savePrefs: \(hiddenApps.sorted())\n"
        try? line.data(using: .utf8)?.write(to: log, options: .atomic)
    }

    private func refresh() {
        isTrusted = MenuBarManager.isTrusted
        guard isTrusted else { return }
        refreshing = true
        // 同步执行，避免异步竞态（日志确认入口）
        let items = MenuBarManager.menuBarItems()
        menuBarGroups = MenuBarManager.groupedByApp(items)
        refreshing = false
        // 重新应用已保存的隐藏偏好
        for group in menuBarGroups where hiddenApps.contains(group.name) {
            for item in group.items {
                MenuBarManager.setHidden(item, hidden: true)
            }
        }
    }

    /// 切换某应用的菜单栏图标显示/隐藏
    private func setHidden(_ appName: String, visible: Bool) {
        if visible {
            hiddenApps.remove(appName)
        } else {
            hiddenApps.insert(appName)
        }
        savePrefs()
        guard let group = menuBarGroups.first(where: { $0.name == appName }) else { return }
        for item in group.items {
            MenuBarManager.setHidden(item, hidden: !visible)
        }
    }

    /// 默认规则：仅保留系统应用，隐藏其余全部
    private func applyDefaultRule() {
        for group in menuBarGroups {
            if isSystemApp(group.name) {
                hiddenApps.remove(group.name)
                for item in group.items {
                    MenuBarManager.setHidden(item, hidden: false)
                }
            } else {
                hiddenApps.insert(group.name)
                for item in group.items {
                    MenuBarManager.setHidden(item, hidden: true)
                }
            }
        }
        savePrefs()
    }

    /// 取菜单栏项所属应用的真实图标
    @ViewBuilder
    private func appIcon(for group: (name: String, pid: pid_t, items: [MenuBarItemInfo])) -> some View {
        if let app = NSWorkspace.shared.runningApplications.first(where: { ($0.localizedName ?? "") == group.name || Int($0.processIdentifier) == Int(group.pid) }),
           let appIcon = app.icon {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: isSystemApp(group.name) ? "apple.logo" : "app.dashed")
                .foregroundStyle(isSystemApp(group.name) ? Color.secondary : Color.orange)
        }
    }

    /// 系统应用判定：Apple 出品（bundle 前缀 com.apple）或路径在系统目录
    private func isSystemApp(_ appName: String) -> Bool {
        let app = NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "") == appName
        }
        guard let app else { return false }
        let bundleID = app.bundleIdentifier ?? ""
        if bundleID.hasPrefix("com.apple.") { return true }
        if let url = app.bundleURL {
            let path = url.path
            if path.hasPrefix("/System/") { return true }
        }
        return false
    }
}
