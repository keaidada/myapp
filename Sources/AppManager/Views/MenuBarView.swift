import SwiftUI

struct MenuBarView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var controller = ServiceController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AppManager")
                .font(.headline)
            Divider()
            if store.services.isEmpty {
                Text("暂无服务")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(store.services.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }) { service in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor(service))
                            .frame(width: 6, height: 6)
                        Text(service.name)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            Task { _ = try? await controller.launch(service) }
                        } label: {
                            Image(systemName: "play.fill")
                                .frame(width: 20)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .task {
            viewModel.start(store: store)
        }
    }

    private func statusColor(_ service: ManagedService) -> Color {
        switch viewModel.statuses[service.id] ?? .unknown {
        case .healthy: .green
        case .down: .red
        case .unknown: .gray
        }
    }
}
