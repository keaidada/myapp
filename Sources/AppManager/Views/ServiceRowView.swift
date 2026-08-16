import SwiftUI

struct ServiceRowView: View {
    let service: ManagedService
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var isLaunching = false

    private var status: ServiceStatus {
        viewModel.statuses[service.id] ?? .unknown
    }

    private var statusColor: Color {
        switch status {
        case .healthy: .green
        case .down: .red
        case .unknown: .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Image(systemName: service.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isLaunching = true
                Task {
                    defer { isLaunching = false }
                    let controller = ServiceController()
                    _ = try? await controller.launch(service)
                }
            } label: {
                if isLaunching {
                    ProgressView().controlSize(.small)
                } else {
                    Label("启动", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        var parts: [String] = []
        if !service.category.isEmpty { parts.append(service.category) }
        parts.append(status.label)
        return parts.joined(separator: " · ")
    }
}
