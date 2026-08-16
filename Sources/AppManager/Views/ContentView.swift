import SwiftUI

struct ContentView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedCategory: String? = "全部"
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingTemplates = false
    @State private var editingService: ManagedService?

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
            ToolbarItem(placement: .primaryAction) {
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
        .sheet(item: $editingService) { service in
            EditServiceView(service: service) { updated in
                try? store.update(updated)
            }
        }
        .task {
            viewModel.start(store: store)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
