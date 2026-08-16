import SwiftUI

struct ServiceRowView: View {
    let service: ManagedService
    @State private var isLaunching = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: service.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                Text(service.kind.displayName + (service.category.isEmpty ? "" : " · \(service.category)"))
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
}
