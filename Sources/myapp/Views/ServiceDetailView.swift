import SwiftUI

struct ServiceDetailView: View {
    let service: ManagedService
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(ServiceStore.self) private var store
    @State private var showingEditor = false

    /// 实时从 store 读取最新数据（编辑保存后自动刷新）
    private var currentService: ManagedService {
        store.services.first { $0.id == service.id } ?? service
    }

    private var resource: ProcessSample? {
        viewModel.resources[service.id]
    }

    var body: some View {
        Form {
            Section("基本信息") {
                LabeledContent("名称", value: currentService.name)
                LabeledContent("分类", value: currentService.category.isEmpty ? "—" : currentService.category)
                LabeledContent("类型", value: currentService.kind.displayName)
                switch currentService.kind {
                case .app:
                    LabeledContent("应用路径", value: currentService.appPath ?? "—")
                case .url:
                    LabeledContent("网址", value: currentService.url ?? "—")
                case .command:
                    LabeledContent("启动命令", value: currentService.command ?? "—")
                }
                // 界面地址：点「打开」用的地址
                LabeledContent("界面地址", value: currentService.url ?? "未设置（点编辑…填写）")
            }

            Section("操作") {
                HStack {
                    Button {
                        Task {
                            let result = (try? await ServiceController().open(currentService))
                                ?? CommandResult(exitCode: -1, stdout: "", stderr: "打开失败")
                            if result.exitCode != 0 {
                                // 忽略静默错误，交给主界面
                            }
                        }
                    } label: {
                        Label("打开界面", systemImage: "safari")
                    }
                    .disabled(!status.isHealthy)
                    .help(status.isHealthy ? "在浏览器打开界面" : "服务未运行，无法打开")

                    Spacer()

                    Button("编辑…") {
                        showingEditor = true
                    }
                }
            }

            Section("状态") {
                LabeledContent("健康状态", value: statusLabel)
                if currentService.checkURL != nil {
                    LabeledContent("健康检查地址", value: currentService.checkURL ?? "—")
                }
                if currentService.statusCommand != nil {
                    LabeledContent("状态命令", value: currentService.statusCommand ?? "—")
                }
            }

            Section("资源占用") {
                if let resource {
                    resourceRow(label: "CPU", value: resource.cpu, icon: "cpu")
                    resourceRow(label: "内存", value: resource.mem, icon: "memorychip")
                    LabeledContent("进程", value: "\(resource.pid) · \(resource.command)")
                } else if currentService.pidPattern != nil {
                    LabeledContent("资源", value: "等待采样…")
                } else {
                    LabeledContent("资源", value: "未配置进程名匹配")
                }
            }

            Section("控制命令") {
                LabeledContent("启动", value: currentService.startCommand ?? "—")
                LabeledContent("停止", value: currentService.stopCommand ?? "—")
                LabeledContent("重启", value: currentService.restartCommand ?? "—")
            }

            if !currentService.variables.isEmpty {
                Section("模板变量") {
                    ForEach(currentService.variables.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }

            if !currentService.tags.isEmpty {
                Section("标签") {
                    FlowLayout(spacing: 6) {
                        ForEach(currentService.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                TagCapsule(text: tag)
                                Button {
                                    try? store.removeTag(tag, from: [service.id])
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("移除「\(tag)」标签")
                            }
                        }
                    }
                }
            } else {
                Section("标签") {
                    Text("无标签")
                        .foregroundStyle(.secondary)
                    Text("点「编辑…」可添加标签")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(currentService.name)
        .sheet(isPresented: $showingEditor) {
            EditServiceView(service: currentService) { updated in
                try? store.update(updated)
            }
        }
    }

    private var statusLabel: String {
        if case .healthy(let ms) = status {
            return "正常 · \(ms)ms"
        }
        return status.label
    }

    private var status: ServiceStatus {
        viewModel.statuses[service.id] ?? .unknown
    }

    private func resourceRow(label: String, value: Double, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            ProgressView(value: min(value / 100.0, 1.0))
                .frame(width: 120)
            Text(String(format: "%.1f%%", value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
