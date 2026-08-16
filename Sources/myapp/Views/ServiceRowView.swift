import SwiftUI

struct ServiceRowView: View {
    let service: ManagedService
    var onTagTap: ((String) -> Void)? = nil
    var onEditTags: (() -> Void)? = nil
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(CommandLog.self) private var log
    @State private var controller = ServiceController()
    @State private var isLaunching = false
    @State private var isOpening = false
    @State private var output: CommandResult?
    @State private var showOutput = false

    private var status: ServiceStatus {
        viewModel.statuses[service.id] ?? .unknown
    }

    private var statusColor: Color {
        switch status {
        case .healthy, .running: .green
        case .down: .red
        case .stopped: .gray
        case .unknown: .gray.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            ServiceIconView(service: service, size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !service.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(service.tags.prefix(3), id: \.self) { tag in
                            Button {
                                onTagTap?(tag)
                            } label: {
                                Text(tag)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("点击查看「\(tag)」分类下的所有服务")
                        }
                        if service.tags.count > 3 {
                            Text("+\(service.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if service.restartCommand != nil {
                    controlButton("重启", systemImage: "arrow.clockwise") { try await controller.restart(service) }
                }
                Button {
                    Task {
                        let status = await controller.status(service)
                        viewModel.statuses[service.id] = status
                        if let cmd = service.statusCommand {
                            let result = (try? await controller.runStatus(service)) ?? CommandResult(exitCode: -1, stdout: "", stderr: "状态查询失败")
                            log.record(serviceName: service.name, command: cmd, result: result)
                        }
                    }
                } label: {
                    Label("状态", systemImage: "stethoscope")
                }
                .controlSize(.small)

                Button {
                    onEditTags?()
                } label: {
                    Label("标签", systemImage: "tag")
                }
                .controlSize(.small)
                .help("管理该服务的标签")

                // 打开界面：仅服务运行时可用
                Button {
                    isOpening = true
                    Task {
                        defer { isOpening = false }
                        let result = (try? await controller.open(service))
                            ?? CommandResult(exitCode: -1, stdout: "", stderr: "打开失败")
                        if result.exitCode != 0 {
                            output = result
                            showOutput = true
                        }
                    }
                } label: {
                    Label("打开", systemImage: "safari")
                }
                .controlSize(.small)
                .disabled(!status.isHealthy)
                .help(status.isHealthy ? "打开界面（⌘O）" : "服务未运行，无法打开")

                // 主按钮：运行中 → 关闭；未运行 → 启动
                if status.isHealthy {
                    mainActionButton.buttonStyle(.bordered).controlSize(.small)
                } else {
                    mainActionButton.buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showOutput) {
            if let output {
                CommandOutputView(result: output)
            }
        }
    }

    /// 主操作按钮：运行中关闭、未运行启动
    private var mainActionButton: Button<some View> {
        Button {
            isLaunching = true
            Task {
                defer { isLaunching = false }
                let result: CommandResult
                if status.isHealthy {
                    result = (try? await controller.quit(service))
                        ?? CommandResult(exitCode: -1, stdout: "", stderr: "关闭失败")
                } else {
                    result = (try? await controller.launch(service))
                        ?? CommandResult(exitCode: -1, stdout: "", stderr: "启动失败")
                }
                log.record(
                    serviceName: service.name,
                    command: CommandLogging.launchCommandText(for: service),
                    result: result
                )
                // 立即刷新该服务状态
                viewModel.statuses[service.id] = await controller.status(service)
                if result.exitCode != 0 {
                    output = result
                    showOutput = true
                }
            }
        } label: {
            if isLaunching {
                ProgressView().controlSize(.small)
            } else if status.isHealthy {
                Label("关闭", systemImage: "stop.fill")
            } else {
                Label("启动", systemImage: "play.fill")
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
                log.record(serviceName: service.name, command: title, result: result)
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
