import SwiftUI

struct ContentView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedCategory: String? = "全部"
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingTemplates = false
    @State private var showingHistory = false
    @State private var editingService: ManagedService?
    @State private var exporting = false
    @State private var importing = false
    @State private var alertMessage: String?
    @State private var isBatchRunning = false
    @State private var batchSummary: BatchOperations.Summary?

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
                        Button("全部启动") { runBatch(.launch) }
                        Button("全部停止") { runBatch(.stop) }
                        Button("全部重启") { runBatch(.restart) }
                    } label: {
                        if isBatchRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("批量操作", systemImage: "play.circle.stack")
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
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .sheet(item: $editingService) { service in
            EditServiceView(service: service) { updated in
                try? store.update(updated)
            }
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

    private enum BatchOp {
        case launch, stop, restart
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
