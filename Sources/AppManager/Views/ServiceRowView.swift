import SwiftUI

struct ServiceRowView: View {
    let service: ManagedService
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var controller = ServiceController()
    @State private var isLaunching = false
    @State private var output: CommandResult?
    @State private var showOutput = false

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

            HStack(spacing: 6) {
                if service.stopCommand != nil {
                    controlButton("停止", systemImage: "stop.fill") { try await controller.stop(service) }
                }
                if service.restartCommand != nil {
                    controlButton("重启", systemImage: "arrow.clockwise") { try await controller.restart(service) }
                }
                Button {
                    Task {
                        let status = (try? await controller.status(service)) ?? .unknown
                        viewModel.statuses[service.id] = status
                    }
                } label: {
                    Label("状态", systemImage: "stethoscope")
                }
                .controlSize(.small)

                Button {
                    isLaunching = true
                    Task {
                        defer { isLaunching = false }
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
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showOutput) {
            if let output {
                CommandOutputView(result: output)
            }
        }
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        action: @escaping () async throws -> CommandResult
    ) -> some View {
        Button {
            Task {
                let result = (try? await action()) ?? CommandResult(exitCode: -1, stdout: "", stderr: "执行失败")
                output = result
                showOutput = true
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .controlSize(.small)
    }

    private var statusText: String {
        var parts: [String] = []
        if !service.category.isEmpty { parts.append(service.category) }
        parts.append(status.label)
        return parts.joined(separator: " · ")
    }
}
