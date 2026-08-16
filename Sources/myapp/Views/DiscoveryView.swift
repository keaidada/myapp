import SwiftUI
import AppKit

struct DiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceStore.self) private var store
    @State private var tab: DiscoveryTab = .apps
    @State private var apps: [InstalledApp] = []
    @State private var brewServices: [BrewService] = []
    @State private var searchText = ""
    @State private var isLoadingBrew = false
    @State private var brewError: String?
    @State private var isAddingApps = false
    @State private var isAddingBrew = false

    enum DiscoveryTab: String, CaseIterable, Identifiable {
        case apps = "已安装应用"
        case brew = "Homebrew 服务"
        var id: String { rawValue }
    }

    private var existingNames: Set<String> {
        Set(store.services.map(\.name))
    }

    private var notAddedApps: [InstalledApp] {
        apps.filter { !existingNames.contains($0.name) }
    }

    private var notAddedBrew: [BrewService] {
        brewServices.filter { !existingNames.contains($0.name) }
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredBrew: [BrewService] {
        guard !searchText.isEmpty else { return brewServices }
        return brewServices.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("来源", selection: $tab) {
                    ForEach(DiscoveryTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                switch tab {
                case .apps:
                    appList
                case .brew:
                    brewList
                }
            }
            .navigationTitle("从系统发现并添加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "搜索…")
            .task {
                await loadTab(tab)
            }
            .onChange(of: tab) { _, newTab in
                Task { await loadTab(newTab) }
            }
        }
        .frame(width: 620, height: 520)
    }

    // ── 已安装应用 ──
    private var appList: some View {
        VStack(spacing: 0) {
            addAllBar(count: notAddedApps.count, label: isAddingApps ? "正在添加…" : "全部添加应用", isBusy: isAddingApps) {
                addAllApps()
            }
            List(filteredApps) { app in
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                        Text(app.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    addAppButton(app)
                }
                .padding(.vertical, 2)
            }
            .overlay {
                if apps.isEmpty {
                    ProgressView("正在扫描应用…")
                }
            }
        }
    }

    private func addAppButton(_ app: InstalledApp) -> some View {
        let added = existingNames.contains(app.name)
        return Button(added ? "已添加" : "添加") {
            guard !added else { return }
            let service = ManagedService(
                name: app.name,
                category: "应用",
                icon: "app",
                kind: .app,
                appPath: app.path,
                appIconData: appIconData(for: app.path)
            )
            try? store.add(service)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(added)
    }

    // ── Homebrew 服务 ──
    private var brewList: some View {
        VStack(spacing: 0) {
            addAllBar(count: notAddedBrew.count, label: isAddingBrew ? "正在添加…" : "全部添加服务", isBusy: isAddingBrew) {
                guard !isAddingBrew else { return }
                isAddingBrew = true
                try? store.addAll(notAddedBrew.map { $0.makeService() })
                isAddingBrew = false
            }
            Group {
                if let brewError {
                    ContentUnavailableView(
                        "无法读取 Homebrew 服务",
                        systemImage: "exclamationmark.triangle",
                        description: Text(brewError)
                    )
                } else if filteredBrew.isEmpty && !isLoadingBrew {
                    ContentUnavailableView(
                        "未发现 Homebrew 服务",
                        systemImage: "server.rack",
                        description: Text("本机暂无 brew services 管理的服务")
                    )
                } else {
                    List(filteredBrew) { service in
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                Text(statusText(service))
                                    .font(.caption)
                                    .foregroundStyle(statusColor(service))
                            }
                            Spacer()
                            addBrewButton(service)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .overlay {
                if isLoadingBrew && brewServices.isEmpty {
                    ProgressView("正在读取 brew services list…")
                }
            }
        }
    }

    private func addBrewButton(_ service: BrewService) -> some View {
        let added = existingNames.contains(service.name)
        return Button(added ? "已添加" : "添加") {
            guard !added else { return }
            try? store.add(service.makeService())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(added)
    }

    // ── 顶部"全部添加"工具条 ──
    private func addAllBar(count: Int, label: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        HStack {
            Text(count > 0 ? "还有 \(count) 项未添加" : "已全部添加")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: action) {
                if isBusy {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(label)
                    }
                } else {
                    Label(label, systemImage: "plus.circle.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(count == 0 || isBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// 异步批量添加全部应用：图标 PNG 编码放后台线程，避免主线程卡死
    private func addAllApps() {
        guard !isAddingApps, !notAddedApps.isEmpty else { return }
        isAddingApps = true
        let targets = notAddedApps
        Task {
            // 主线程取图标引用（系统缓存，很快）
            let pairs = targets.map { (app: $0, image: NSWorkspace.shared.icon(forFile: $0.path)) }
            // 后台线程做 PNG 编码（109 个应用的编码是卡顿根源）
            let services = await Task.detached(priority: .userInitiated) {
                pairs.map { pair in
                    ManagedService(
                        name: pair.app.name,
                        category: "应用",
                        icon: "app",
                        kind: .app,
                        appPath: pair.app.path,
                        appIconData: Self.pngData(from: pair.image)
                    )
                }
            }.value
            try? store.addAll(services)
            isAddingApps = false
        }
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }

    // ── 辅助 ──
    private func loadTab(_ tab: DiscoveryTab) async {
        switch tab {
        case .apps:
            if apps.isEmpty {
                apps = AppScanner.scan()
            }
        case .brew:
            if brewServices.isEmpty && !isLoadingBrew {
                isLoadingBrew = true
                defer { isLoadingBrew = false }
                brewServices = await BrewDiscoverer.discover()
                if brewServices.isEmpty {
                    brewError = "brew services list 无输出，可能未安装 Homebrew 或没有服务"
                } else {
                    brewError = nil
                }
            }
        }
    }

    private func statusText(_ service: BrewService) -> String {
        switch service.status {
        case "started": "运行中"
        case "stopped": "已停止"
        case "error": "异常"
        default: service.status
        }
    }

    private func statusColor(_ service: BrewService) -> Color {
        switch service.status {
        case "started": .green
        case "error": .red
        default: .secondary
        }
    }

    private func appIconData(for path: String) -> Data? {
        let image = NSWorkspace.shared.icon(forFile: path)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }
}
