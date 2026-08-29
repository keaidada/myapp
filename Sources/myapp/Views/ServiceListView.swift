import SwiftUI

struct ServiceListView: View {
    let services: [ManagedService]
    @Binding var selection: Set<ManagedService.ID>
    let onEdit: (ManagedService) -> Void
    let onDelete: (ManagedService) -> Void
    var onMove: ((IndexSet, Int) -> Void)? = nil
    var onTagTap: ((String) -> Void)? = nil
    var onEditTags: ((ManagedService) -> Void)? = nil
    var showsLaunchCount = false
    var isSelectionMode = false
    var selectedCount = 0
    var layoutMode: LayoutMode = .list
    var onLaunchSelected: (() -> Void)? = nil
    var onStopSelected: (() -> Void)? = nil
    var onRestartSelected: (() -> Void)? = nil
    var onDeleteSelected: (() -> Void)? = nil
    var onAddTagSelected: (() -> Void)? = nil
    var onClearSelection: (() -> Void)? = nil
    @State private var detailServiceID: ManagedService.ID?

    var body: some View {
        NavigationStack {
            switch layoutMode {
            case .list:
                listLayout
            case .grid:
                gridLayout
            }
        }
    }

    // MARK: - 列表布局

    private var listLayout: some View {
        List(selection: $selection) {
            ForEach(services) { service in
                if isSelectionMode {
                    selectableRow(service)
                } else {
                    ServiceRowView(service: service, onTagTap: onTagTap, onEditTags: { onEditTags?(service) }, showsLaunchCount: showsLaunchCount)
                        .contentShape(Rectangle())
                        .onTapGesture { detailServiceID = service.id }
                        .contextMenu {
                            Button("标签…") { onEditTags?(service) }
                            Button("编辑…") { onEdit(service) }
                            Button("删除", role: .destructive) { onDelete(service) }
                        }
                }
            }
            .onMove { indices, offset in
                onMove?(indices, offset)
            }
        }
        .navigationDestination(item: $detailServiceID) { id in
            if let service = services.first(where: { $0.id == id }) {
                ServiceDetailView(service: service)
            }
        }
        .overlay {
            if services.isEmpty { emptyView }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedCount > 0 { selectionBar }
        }
    }

    // MARK: - 卡片 / 积木布局

    private var gridLayout: some View {
        Group {
            if services.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(services) { service in
                            AppGridCardView(
                                service: service,
                                onSelect: { detailServiceID = service.id }
                            )
                            .contextMenu {
                                Button("标签…") { onEditTags?(service) }
                                Button("编辑…") { onEdit(service) }
                                Button("删除", role: .destructive) { onDelete(service) }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationDestination(item: $detailServiceID) { id in
            if let service = services.first(where: { $0.id == id }) {
                ServiceDetailView(service: service)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedCount > 0 { selectionBar }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "暂无服务",
            systemImage: "square.stack.3d.up.slash",
            description: Text("点右上角 + 添加一个服务")
        )
    }

    /// 多选模式下的行：复选框 + 点击切换选中
    private func selectableRow(_ service: ManagedService) -> some View {
        let isSelected = selection.contains(service.id)
        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            ServiceRowView(service: service)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selection.remove(service.id)
            } else {
                selection.insert(service.id)
            }
        }
        .contextMenu {
            Button("编辑…") { onEdit(service) }
            Button("删除", role: .destructive) { onDelete(service) }
        }
    }

    /// 选中服务后底部弹出的批量操作栏
    private var selectionBar: some View {
        HStack(spacing: 10) {
            Text("已选择 \(selectedCount) 项")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("启动") { onLaunchSelected?() }
            Button("停止") { onStopSelected?() }
            Button("重启") { onRestartSelected?() }
            Button("删除", role: .destructive) { onDeleteSelected?() }
            Button("标签") { onAddTagSelected?() }
            Divider().frame(height: 16)
            Button {
                onClearSelection?()
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("清除选择")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .animation(.easeInOut(duration: 0.15), value: selectedCount)
    }
}
