import SwiftUI

struct ServiceListView: View {
    let services: [ManagedService]
    let onEdit: (ManagedService) -> Void
    let onDelete: (ManagedService) -> Void

    var body: some View {
        List(services) { service in
            ServiceRowView(service: service)
                .contextMenu {
                    Button("编辑…") { onEdit(service) }
                    Button("删除", role: .destructive) { onDelete(service) }
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
    }
}
