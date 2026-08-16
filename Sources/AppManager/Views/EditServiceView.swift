import SwiftUI

struct EditServiceView: View {
    @Environment(\.dismiss) private var dismiss
    let service: ManagedService?
    let onSave: (ManagedService) -> Void

    @State private var name: String
    @State private var category: String
    @State private var icon: String
    @State private var kind: ServiceKind
    @State private var appPath: String
    @State private var url: String
    @State private var command: String
    @State private var checkURL: String
    @State private var statusCommand: String
    @State private var startCommand: String
    @State private var stopCommand: String
    @State private var restartCommand: String
    @State private var pidPattern: String
    @State private var variablesText: String
    @State private var showingIconPicker = false

    init(service: ManagedService?, onSave: @escaping (ManagedService) -> Void) {
        self.service = service
        self.onSave = onSave
        _name = State(initialValue: service?.name ?? "")
        _category = State(initialValue: service?.category ?? "")
        _icon = State(initialValue: service?.icon ?? "square.stack.3d.up")
        _kind = State(initialValue: service?.kind ?? .command)
        _appPath = State(initialValue: service?.appPath ?? "")
        _url = State(initialValue: service?.url ?? "")
        _command = State(initialValue: service?.command ?? "")
        _checkURL = State(initialValue: service?.checkURL ?? "")
        _statusCommand = State(initialValue: service?.statusCommand ?? "")
        _startCommand = State(initialValue: service?.startCommand ?? "")
        _stopCommand = State(initialValue: service?.stopCommand ?? "")
        _restartCommand = State(initialValue: service?.restartCommand ?? "")
        _pidPattern = State(initialValue: service?.pidPattern ?? "")
        let vars = service?.variables ?? [:]
        _variablesText = State(initialValue: vars.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))
    }

    var body: some View {
        Form {
            TextField("名称", text: $name)
            TextField("分类", text: $category)

            HStack {
                Text("图标")
                Spacer()
                Button {
                    showingIconPicker = true
                } label: {
                    HStack {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        Text("选择…")
                    }
                }
                .buttonStyle(.plain)
            }
            .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                iconPicker
            }

            Picker("类型", selection: $kind) {
                ForEach(ServiceKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.segmented)

            switch kind {
            case .app:
                TextField("应用路径（如 /Applications/Safari.app）", text: $appPath)
            case .url:
                TextField("网址（如 http://localhost:4000）", text: $url)
            case .command:
                TextField("启动命令（如 brew services start redis）", text: $command)
            }

            Section("监控与状态（可选）") {
                TextField("健康检查地址", text: $checkURL, prompt: Text("http://localhost:4000/health"))
                TextField("状态命令", text: $statusCommand, prompt: Text("pgrep -f my-service"))
                TextField("进程名匹配（资源监控）", text: $pidPattern, prompt: Text("redis-server"))
            }

            Section("控制命令（可选）") {
                TextField("启动", text: $startCommand)
                TextField("停止", text: $stopCommand)
                TextField("重启", text: $restartCommand)
            }

            if kind == .command {
                Section("模板变量（每行 key=value，命令中用 {key} 引用）") {
                    TextEditor(text: $variablesText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(service == nil ? "添加服务" : "编辑服务")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(buildService())
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(width: 520)
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择图标")
                .font(.headline)
            TextField("或输入 SF Symbol 名称", text: $icon)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(IconCatalog.symbols, id: \.self) { symbol in
                    Button {
                        icon = symbol
                        showingIconPicker = false
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .frame(width: 28, height: 28)
                            .background(
                                icon == symbol ? Color.accentColor.opacity(0.25) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(symbol)
                }
            }
            .frame(width: 300)
        }
        .padding(12)
    }

    private func parseVariables(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = String(parts[1])
        }
        return result
    }

    private func buildService() -> ManagedService {
        ManagedService(
            id: service?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.trimmingCharacters(in: .whitespaces),
            icon: icon.trimmingCharacters(in: .whitespaces).isEmpty ? "square.stack.3d.up" : icon,
            kind: kind,
            appPath: kind == .app ? appPath : nil,
            url: kind == .url ? url : nil,
            command: kind == .command ? command : nil,
            checkURL: checkURL.isEmpty ? nil : checkURL,
            statusCommand: statusCommand.isEmpty ? nil : statusCommand,
            startCommand: startCommand.isEmpty ? nil : startCommand,
            stopCommand: stopCommand.isEmpty ? nil : stopCommand,
            restartCommand: restartCommand.isEmpty ? nil : restartCommand,
            pidPattern: pidPattern.isEmpty ? nil : pidPattern,
            sortOrder: service?.sortOrder ?? 0,
            variables: kind == .command ? parseVariables(variablesText) : [:]
        )
    }
}
