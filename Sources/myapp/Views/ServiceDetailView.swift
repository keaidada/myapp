import SwiftUI

struct ServiceDetailView: View {
    let service: ManagedService
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(ServiceStore.self) private var store

    private var resource: ProcessSample? {
        viewModel.resources[service.id]
    }

    var body: some View {
        Form {
            Section("基本信息") {
                LabeledContent("名称", value: service.name)
                LabeledContent("分类", value: service.category.isEmpty ? "—" : service.category)
                LabeledContent("类型", value: service.kind.displayName)
                switch service.kind {
                case .app:
                    LabeledContent("应用路径", value: service.appPath ?? "—")
                case .url:
                    LabeledContent("网址", value: service.url ?? "—")
                case .command:
                    LabeledContent("启动命令", value: service.command ?? "—")
                }
            }

            Section("状态") {
                LabeledContent("健康状态", value: statusLabel)
                if service.checkURL != nil {
                    LabeledContent("检查地址", value: service.checkURL ?? "—")
                }
                if service.statusCommand != nil {
                    LabeledContent("状态命令", value: service.statusCommand ?? "—")
                }
            }

            Section("资源占用") {
                if let resource {
                    resourceRow(label: "CPU", value: resource.cpu, icon: "cpu")
                    resourceRow(label: "内存", value: resource.mem, icon: "memorychip")
                    LabeledContent("进程", value: "\(resource.pid) · \(resource.command)")
                } else if service.pidPattern != nil {
                    LabeledContent("资源", value: "等待采样…")
                } else {
                    LabeledContent("资源", value: "未配置进程名匹配")
                }
            }

            Section("控制命令") {
                LabeledContent("启动", value: service.startCommand ?? "—")
                LabeledContent("停止", value: service.stopCommand ?? "—")
                LabeledContent("重启", value: service.restartCommand ?? "—")
            }

            if !service.variables.isEmpty {
                Section("模板变量") {
                    ForEach(service.variables.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }

            if !service.tags.isEmpty {
                Section("标签") {
                    FlowLayout(spacing: 6) {
                        ForEach(service.tags, id: \.self) { tag in
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
                    Text("编辑服务可添加标签")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(service.name)
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
