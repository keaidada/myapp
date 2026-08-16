import SwiftUI

struct ServiceListView: View {
    let services: [ManagedService]
    @Binding var selection: Set<ManagedService.ID>
    let onEdit: (ManagedService) -> Void
    let onDelete: (ManagedService) -> Void
    var onMove: ((IndexSet, Int) -> Void)? = nil
    var selectedCount = 0
    var onLaunchSelected: (() -> Void)? = nil
    var onStopSelected: (() -> Void)? = nil
    var onRestartSelected: (() -> Void)? = nil
    var onDeleteSelected: (() -> Void)? = nil
    var onClearSelection: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(services) { service in
                    NavigationLink(value: service.id) {
                        ServiceRowView(service: service)
                    }
                    .contextMenu {
                        Button("编辑…") { onEdit(service) }
                        Button("删除", role: .destructive) { onDelete(service) }
                    }
                }
                .onMove { indices, offset in
                    onMove?(indices, offset)
                }
            }
            .navigationDestination(for: ManagedService.ID.self) { id in
                if let service = services.first(where: { $0.id == id }) {
                    ServiceDetailView(service: service)
                }
            }
            .overlay {
                if services.isEmpty {
                    ContentUnavailableView(
                        "暂无服务",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("点右上角 + 添加一个服务")
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if selectedCount > 0 {
                    selectionBar
                }
            }
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
