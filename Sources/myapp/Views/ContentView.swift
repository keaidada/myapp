import SwiftUI

struct ContentView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedCategory: String? = "全部"
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingTemplates = false
    @State private var showingDiscovery = false
    @State private var showingHistory = false
    @State private var editingService: ManagedService?
    @State private var exporting = false
    @State private var importing = false
    @State private var alertMessage: String?
    @State private var isBatchRunning = false
    @State private var batchSummary: BatchOperations.Summary?
    @State private var selectedIDs: Set<ManagedService.ID> = []
    @State private var showDeleteConfirm = false

    private var filteredServices: [ManagedService] {
        store.services
            .filter { selectedCategory == nil || selectedCategory == "全部" || $0.category == selectedCategory }
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.category.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    private var selectedServices: [ManagedService] {
        store.services.filter { selectedIDs.contains($0.id) }
    }

    private var selectionLabel: String {
        selectedIDs.isEmpty ? "批量操作" : "批量操作（\(selectedIDs.count)）"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Text("全部").tag(String?.some("全部"))
                ForEach(store.categories, id: \.self) { category in
                    Text(category).tag(String?.some(category))
                }
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } detail: {
            ServiceListView(
                services: filteredServices,
                selection: $selectedIDs,
                onEdit: { editingService = $0 },
                onDelete: { try? store.delete($0) },
                onMove: { indices, offset in
                    try? store.move(fromOffsets: indices, toOffset: offset)
                }
            )
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索服务…")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !store.services.isEmpty {
                    Menu {
                        Button("全选") { selectAll() }
                        Button("反选") { invertSelection() }
                        Divider()
                        Button("启动选中\(selectedCountSuffix)") { runSelected(.launch) }
                            .disabled(selectedIDs.isEmpty)
                        Button("停止选中\(selectedCountSuffix)") { runSelected(.stop) }
                            .disabled(selectedIDs.isEmpty)
                        Button("重启选中\(selectedCountSuffix)") { runSelected(.restart) }
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
                    Divider()
                    Button {
                        let dir = ServiceStore.defaultFileURL.deletingLastPathComponent()
                        NSWorkspace.shared.open(dir)
                    } label: {
                        Label("打开数据目录", systemImage: "folder")
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
        .sheet(item: $editingService) { service in
            EditServiceView(service: service) { updated in
                try? store.update(updated)
            }
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
            viewModel.start(store: store)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

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
                batchSummary = await BatchOperations.launchAll(selectedServices)
            case .stop:
                batchSummary = await BatchOperations.stopAll(selectedServices)
            case .restart:
                batchSummary = await BatchOperations.restartAll(selectedServices)
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
                batchSummary = await BatchOperations.launchAll(store.services)
            case .stop:
                batchSummary = await BatchOperations.stopAll(store.services)
            case .restart:
                batchSummary = await BatchOperations.restartAll(store.services)
            }
        }
    }
}
