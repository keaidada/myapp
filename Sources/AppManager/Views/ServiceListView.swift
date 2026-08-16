import SwiftUI

struct ServiceListView: View {
    let services: [ManagedService]
    let onEdit: (ManagedService) -> Void
    let onDelete: (ManagedService) -> Void
    @State private var selectedID: ManagedService.ID?

    var body: some View {
        NavigationStack {
            List(selection: $selectedID) {
                ForEach(services) { service in
                    NavigationLink(value: service.id) {
                        ServiceRowView(service: service)
                    }
                    .contextMenu {
                        Button("编辑…") { onEdit(service) }
                        Button("删除", role: .destructive) { onDelete(service) }
                    }
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
        }
    }
}
