import SwiftUI

struct MenuBarView: View {
    @Environment(ServiceStore.self) private var store
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(CommandLog.self) private var log
    @State private var controller = ServiceController()

    private var downServices: [ManagedService] {
        store.services.filter { service in
            if case .down = viewModel.statuses[service.id] ?? .unknown { return true }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("myapp")
                    .font(.headline)
                Spacer()
                Text("离线 \(viewModel.downCount)")
                    .font(.caption)
                    .foregroundStyle(viewModel.hasDownService ? .red : .secondary)
            }
            // 明显的设置入口（Settings scene 在 macOS 里默认藏在应用菜单，很多人找不到）
            Button {
                openSettings()
            } label: {
                Label("设置…", systemImage: "gearshape")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            Divider()

            if !downServices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("离线服务")
                        .font(.caption)
                        .foregroundStyle(.red)
                    ForEach(downServices) { service in
                        HStack(spacing: 8) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text(service.name).lineLimit(1)
                            Spacer()
                            Button {
                                Task {
                                    let result = (try? await controller.launch(service))
                                        ?? CommandResult(exitCode: -1, stdout: "", stderr: "启动失败")
                                    if result.exitCode == 0 {
                                        store.recordLaunch(service.id)
                                    }
                                }
                            } label: {
                                Image(systemName: "play.fill").frame(width: 18)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Divider()
            }

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
                            Task {
                                let result = (try? await controller.launch(service))
                                    ?? CommandResult(exitCode: -1, stdout: "", stderr: "启动失败")
                                if result.exitCode == 0 {
                                    store.recordLaunch(service.id)
                                }
                                log.record(serviceName: service.name,
                                           command: CommandLogging.launchCommandText(for: service),
                                           result: result)
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .frame(width: 18)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(width: 300)
        .task {
            viewModel.start(store: store)
        }
    }

    private func statusColor(_ service: ManagedService) -> Color {
        switch viewModel.statuses[service.id] ?? .unknown {
        case .healthy, .running: .green
        case .down: .red
        case .stopped: .gray
        case .unknown: .gray.opacity(0.5)
        }
    }

    /// 打开设置窗口（等价于菜单栏 myapp → 设置… 或 ⌘,）
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

/// 菜单栏图标：任一服务离线时显示红色警示
struct MenuBarIcon: View {
    @Environment(DashboardViewModel.self) private var viewModel

    var body: some View {
        Image(systemName: viewModel.hasDownService ? "exclamationmark.triangle.fill" : "circle.grid.3x3.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(viewModel.hasDownService ? Color.red : Color.primary)
    }
}
