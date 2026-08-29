import SwiftUI

struct ContentView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(CommandLog.self) private var commandLog
    @State private var filter: SidebarFilter? = .all
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingTemplates = false
    @State private var showingDiscovery = false
    @State private var showingHistory = false
    @State private var showingBatchTag = false
    @State private var editingService: ManagedService?
    @State private var exporting = false
    @State private var importing = false
    @State private var alertMessage: String?
    @State private var isBatchRunning = false
    @State private var batchSummary: BatchOperations.Summary?
    @State private var selectedIDs: Set<ManagedService.ID> = []
    @State private var showDeleteConfirm = false
    @State private var isSelectionMode = false
    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var deleteTagTarget: String?
    @State private var showingTagManager = false
    @State private var editingTagsService: ManagedService?
    @State private var sortMode: SortMode = .smart
    /// 展示布局：列表 / 卡片
    @State private var layoutMode: LayoutMode = .list
    /// 排序用状态快照：点击启动/关闭或轮询更新不会触发重排（避免列表跳动）
    @State private var statusSnapshot: [UUID: Bool] = [:]

    enum SortMode: String, CaseIterable, Identifiable {
        case smart = "运行在上 + 字母序"
        case manual = "手动拖拽排序"
        var id: String { rawValue }
    }

    enum SidebarFilter: Hashable {
        case all
        case category(String)
        case tag(String)
        case untagged
        case running   // 动态标签：运行中
        case stopped   // 动态标签：未运行
        case hot       // 最近热度 Top10

        var label: String {
            switch self {
            case .all: "全部"
            case .category(let c): c
            case .tag(let t): t
            case .untagged: "未打标签"
            case .running: "运行中"
            case .stopped: "未运行"
            case .hot: "最近热度"
            }
        }
    }

    // MARK: - 数据与排序

    private func refreshSortSnapshot() {
        var snapshot: [UUID: Bool] = [:]
        let services = store.services
        let statuses = viewModel.statuses
        for service in services {
            snapshot[service.id] = statuses[service.id]?.isHealthy ?? false
        }
        statusSnapshot = snapshot
    }

    private var filteredServices: [ManagedService] {
        // 有搜索词时跨所有服务搜索，不受当前侧边栏分类/标签限制
        if !searchText.isEmpty {
            if case .hot = filter {
                return store.hotServices(limit: 10).filter { matchesSearch($0, searchText) }
            }
            return store.services.filter { matchesSearch($0, searchText) }
        }
        // 无搜索词：按当前筛选
        if case .hot = filter {
            return store.hotServices(limit: 10)
        }
        return store.services.filter { filterMatches($0) }
    }

    /// 搜索匹配：名称 / 别名 / 分类 / 标签
    private func matchesSearch(_ service: ManagedService, _ text: String) -> Bool {
        service.name.localizedCaseInsensitiveContains(text)
            || service.aliases.contains { $0.localizedCaseInsensitiveContains(text) }
            || service.category.localizedCaseInsensitiveContains(text)
            || service.tags.contains { $0.localizedCaseInsensitiveContains(text) }
    }

    private func filterMatches(_ service: ManagedService) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .all:
            return true
        case .category(let category):
            return service.category == category
        case .tag(let tag):
            return service.tags.contains(tag)
        case .untagged:
            return service.tags.isEmpty
        case .running:
            return viewModel.statuses[service.id]?.isHealthy == true
        case .stopped:
            return viewModel.statuses[service.id]?.isHealthy == false
        case .hot:
            // 热度 Top10 在 filteredServices 中已按热度排序取前 10，此处放行
            return true
        }
    }

    /// 当前是否最近热度视图
    private var isHotFilter: Bool {
        if case .hot = filter { return true }
        return false
    }

    /// 最近热度 Top10 侧边栏入口（明细在右侧主列表展示）
    private var hotSection: some View {
        Section("最近热度") {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Top 10")
                Spacer()
                Text("\(store.hotServices(limit: 10).count) 个")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(SidebarFilter.hot)
            .help("点击查看启动次数最多的 10 个服务")
        }
    }

    /// 动态标签计数（运行中 / 未运行）
    private func runningCount(_ isRunning: Bool) -> Int {
        store.services.reduce(0) { count, service in
            let healthy = viewModel.statuses[service.id]?.isHealthy ?? false
            return count + (healthy == isRunning ? 1 : 0)
        }
    }

    private var sortedServices: [ManagedService] {
        if case .hot = filter {
            return filteredServices
        }
        switch sortMode {
        case .smart:
            return SortUtil.smartSorted(filteredServices, runningSnapshot: statusSnapshot)
        case .manual:
            return SortUtil.manualSorted(filteredServices)
        }
    }

    private var selectedServices: [ManagedService] {
        store.services.filter { selectedIDs.contains($0.id) }
    }

    private var selectionLabel: String {
        selectedIDs.isEmpty ? "批量操作" : "批量操作（\(selectedIDs.count)）"
    }

    /// 布局切换按钮（列表 / 卡片）
    private func layoutButton(_ mode: LayoutMode) -> some View {
        Button {
            layoutMode = mode
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(layoutMode == mode ? Color.accentColor : Color.secondary)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(layoutMode == mode ? Color.accentColor.opacity(0.15) : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(mode.help)
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List(selection: $filter) {
            Section("服务") {
                Label("全部", systemImage: "square.grid.2x2").tag(SidebarFilter.all)
                ForEach(store.categories, id: \.self) { category in
                    Label(category, systemImage: SidebarIcons.icon(forCategory: category))
                        .tag(SidebarFilter.category(category))
                }
            }
            hotSection
            Section {
                HStack {
                    Text("标签")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        showingTagManager = true
                    } label: {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("打开标签管理窗口")
                }
            } header: {
                Text("标签")
            }
            Section("标签") {
                Label("未打标签", systemImage: "tag.slash").tag(SidebarFilter.untagged)
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("运行中")
                    Spacer()
                    Text("\(runningCount(true))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(SidebarFilter.running)
                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("未运行")
                    Spacer()
                    Text("\(runningCount(false))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(SidebarFilter.stopped)
                ForEach(store.allTags, id: \.self) { tag in
                    HStack(spacing: 6) {
                        Image(systemName: SidebarIcons.icon(forTag: tag))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tag)
                        Spacer()
                        Text("\(store.count(of: tag))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(SidebarFilter.tag(tag))
                    .contextMenu {
                        Button("启动该标签全部服务") {
                            runTagBatch(.launch, tag: tag)
                        }
                        Button("停止该标签全部服务") {
                            runTagBatch(.stop, tag: tag)
                        }
                        Divider()
                        Button("重命名…") {
                            renameTarget = tag
                            renameText = tag
                        }
                        Button("删除标签", role: .destructive) {
                            deleteTagTarget = tag
                        }
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    }

    // MARK: - 工具栏

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !store.services.isEmpty {
                Button {
                    isSelectionMode.toggle()
                    if !isSelectionMode { selectedIDs = [] }
                } label: {
                    Label(isSelectionMode ? "完成" : "选择", systemImage: "checkmark.circle")
                }
                .help(isSelectionMode ? "退出多选模式" : "进入多选模式（点击行即可勾选）")

                // 列表 / 卡片布局切换：两个紧凑图标按钮，与工具栏风格统一
                HStack(spacing: 2) {
                    layoutButton(.list)
                    layoutButton(.grid)
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray.opacity(0.1))
                )

                Menu {
                    Picker("排序", selection: $sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button("全选") { selectAll() }
                    Button("反选") { invertSelection() }
                    Divider()
                    Button("打开选中\(selectedCountSuffix)") { openSelected() }
                        .keyboardShortcut("o", modifiers: .command)
                        .disabled(selectedIDs.isEmpty)
                    Divider()
                    Button("启动选中\(selectedCountSuffix)") { runSelected(.launch) }
                        .disabled(selectedIDs.isEmpty)
                    Button("停止选中\(selectedCountSuffix)") { runSelected(.stop) }
                        .disabled(selectedIDs.isEmpty)
                    Button("重启选中\(selectedCountSuffix)") { runSelected(.restart) }
                        .disabled(selectedIDs.isEmpty)
                    Button("打标签\(selectedCountSuffix)") { showingBatchTag = true }
                        .disabled(selectedIDs.isEmpty)
                    Button("删除选中\(selectedCountSuffix)", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(selectedIDs.isEmpty)
                    Divider()
                    Button("全部启动") { runBatch(.launch) }
                    Button("全部停止") { runBatch(.stop) }
                    Button("全部重启") { runBatch(.restart) }
                } label: {
                    if isBatchRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(selectionLabel, systemImage: "checklist")
                    }
                }
                .disabled(isBatchRunning)
            }

            Button {
                showingHistory = true
            } label: {
                Label("运行历史", systemImage: "clock.arrow.circlepath")
            }

            Menu {
                Button {
                    exporting = true
                } label: {
                    Label("导出配置…", systemImage: "square.and.arrow.up")
                }
                .disabled(store.services.isEmpty)
                Button {
                    importing = true
                } label: {
                    Label("导入配置…", systemImage: "square.and.arrow.down")
                }
                Button {
                    showingTagManager = true
                } label: {
                    Label("标签管理…", systemImage: "tag")
                }
                Button {
                    Task {
                        await viewModel.refreshNow(store: store)
                        refreshSortSnapshot()
                    }
                } label: {
                    Label("立即刷新状态", systemImage: "arrow.clockwise")
                }
                Divider()
                Button {
                    let dir = ServiceStore.defaultFileURL.deletingLastPathComponent()
                    NSWorkspace.shared.open(dir)
                } label: {
                    Label("打开数据目录", systemImage: "folder")
                }
                Divider()
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("设置…", systemImage: "gearshape")
                }
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }

            Menu {
                Button {
                    showingEditor = true
                } label: {
                    Label("空白服务", systemImage: "square.stack.3d.up")
                }
                Button {
                    showingTemplates = true
                } label: {
                    Label("从模板添加", systemImage: "books.vertical")
                }
                Button {
                    showingDiscovery = true
                } label: {
                    Label("从系统发现…", systemImage: "magnifyingglass.circle")
                }
            } label: {
                Label("添加服务", systemImage: "plus")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        applyOverlays(mainContent)
    }

    /// 主内容：侧栏 + 列表 + 搜索 + 工具栏
    private var mainContent: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ServiceListView(
                services: sortedServices,
                selection: $selectedIDs,
                onEdit: { editingService = $0 },
                onDelete: { try? store.delete($0) },
                onMove: sortMode == .manual ? { indices, offset in
                    try? store.move(fromOffsets: indices, toOffset: offset)
                } : nil,
                onTagTap: { tag in
                    filter = .tag(tag)
                    searchText = ""
                },
                onEditTags: { service in
                    editingTagsService = service
                },
                showsLaunchCount: isHotFilter,
                isSelectionMode: isSelectionMode,
                selectedCount: selectedIDs.count,
                layoutMode: layoutMode,
                onLaunchSelected: { runSelected(.launch) },
                onStopSelected: { runSelected(.stop) },
                onRestartSelected: { runSelected(.restart) },
                onDeleteSelected: { showDeleteConfirm = true },
                onAddTagSelected: { showingBatchTag = true },
                onClearSelection: { selectedIDs = [] }
            )
        }
    }

    /// 弹窗 / 对话框等修饰链（拆开降低类型检查压力）
    private func applyOverlays(_ content: some View) -> some View {
        content
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索服务…")
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingEditor) {
            EditServiceView(service: nil) { service in
                try? store.add(service)
            }
        }
        .sheet(isPresented: $showingTemplates) {
            TemplatePickerView { template in
                try? store.add(template.makeService())
            }
        }
        .sheet(isPresented: $showingDiscovery) {
            DiscoveryView()
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerView()
        }
        .sheet(isPresented: $showingBatchTag) {
            BatchTagView(
                selectedCount: selectedIDs.count,
                existingTags: store.allTags,
                onApply: { tag in
                    try? store.addTag(tag, to: selectedIDs)
                },
                onRemove: { tag in
                    try? store.removeTag(tag, from: selectedIDs)
                }
            )
        }
        .sheet(item: $editingService) { service in
            EditServiceView(service: service) { updated in
                try? store.update(updated)
            }
        }
        .sheet(item: $editingTagsService) { service in
            ServiceTagEditor(service: service)
        }
        .alert("重命名标签", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("新名称", text: $renameText)
            Button("确定") {
                if let old = renameTarget {
                    try? store.renameTag(old, to: renameText)
                }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        } message: {
            Text("所有使用该标签的服务都会同步更新")
        }
        .confirmationDialog(
            "删除标签「\(deleteTagTarget ?? "")」？",
            isPresented: Binding(
                get: { deleteTagTarget != nil },
                set: { if !$0 { deleteTagTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let tag = deleteTagTarget {
                    try? store.deleteTag(tag)
                }
                deleteTagTarget = nil
            }
            Button("取消", role: .cancel) { deleteTagTarget = nil }
        } message: {
            Text("将从所有服务上移除该标签")
        }
        .confirmationDialog(
            "删除选中的 \(selectedIDs.count) 个服务？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                let removed = (try? store.deleteAll(selectedIDs)) ?? 0
                selectedIDs = []
                if removed > 0 {
                    alertMessage = "已删除 \(removed) 个服务"
                }
            }
            Button("取消", role: .cancel) {}
        }
        .fileExporter(
            isPresented: $exporting,
            document: ServicesDocument(data: (try? store.exportData()) ?? Data()),
            contentType: .json,
            defaultFilename: "services"
        ) { result in
            if case .failure(let error) = result {
                alertMessage = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    try store.importFrom(url: url)
                } catch {
                    alertMessage = "导入失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                alertMessage = "导入失败：\(error.localizedDescription)"
            }
        }
        .alert(
            "批量操作完成",
            isPresented: Binding(
                get: { batchSummary != nil },
                set: { if !$0 { batchSummary = nil } }
            )
        ) {
            Button("好") { batchSummary = nil }
        } message: {
            Text(batchSummary?.text ?? "")
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("好") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .task {
            viewModel.commandLog = commandLog
            viewModel.onFirstRefresh = { [weak viewModel] in
                // 首次状态检测完成后刷新排序快照，让"运行在上"生效
                refreshSortSnapshot()
            }
            viewModel.start(store: store)
            refreshSortSnapshot()
        }
        .onChange(of: store.services) { _, _ in
            refreshSortSnapshot()
        }
        .onChange(of: sortMode) { _, _ in
            refreshSortSnapshot()
        }
 
    }

    // MARK: - 操作

    private var selectedCountSuffix: String {
        selectedIDs.isEmpty ? "" : "（\(selectedIDs.count)）"
    }

    private enum BatchOp {
        case launch, stop, restart
    }

    private func selectAll() {
        selectedIDs = Set(filteredServices.map(\.id))
    }

    private func invertSelection() {
        let visible = Set(filteredServices.map(\.id))
        selectedIDs = visible.subtracting(selectedIDs)
    }

    private func runSelected(_ op: BatchOp) {
        guard !isBatchRunning, !selectedServices.isEmpty else { return }
        isBatchRunning = true
        Task {
            defer { isBatchRunning = false }
            switch op {
            case .launch:
                batchSummary = await BatchOperations.launchAll(selectedServices, onLaunched: { store.recordLaunch($0.id) })
            case .stop:
                batchSummary = await BatchOperations.stopAll(selectedServices)
            case .restart:
                batchSummary = await BatchOperations.restartAll(selectedServices)
            }
        }
    }

    private func openSelected() {
        guard let service = selectedServices.first else { return }
        Task {
            let result = (try? await ServiceController().open(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "打开失败")
            if result.exitCode != 0 {
                alertMessage = "打开失败：\(result.stderr)"
            }
        }
    }

    private func runTagBatch(_ op: BatchOp, tag: String) {
        guard !isBatchRunning else { return }
        let targets = store.services.filter { $0.tags.contains(tag) }
        guard !targets.isEmpty else { return }
        isBatchRunning = true
        Task {
            defer { isBatchRunning = false }
            switch op {
            case .launch:
                batchSummary = await BatchOperations.launchAll(targets, onLaunched: { store.recordLaunch($0.id) })
            case .stop:
                batchSummary = await BatchOperations.stopAll(targets)
            case .restart:
                batchSummary = await BatchOperations.restartAll(targets)
            }
        }
    }

    private func runBatch(_ op: BatchOp) {
        guard !isBatchRunning else { return }
        isBatchRunning = true
        Task {
            defer { isBatchRunning = false }
            switch op {
            case .launch:
                batchSummary = await BatchOperations.launchAll(store.services, onLaunched: { store.recordLaunch($0.id) })
            case .stop:
                batchSummary = await BatchOperations.stopAll(store.services)
            case .restart:
                batchSummary = await BatchOperations.restartAll(store.services)
            }
        }
    }
}
