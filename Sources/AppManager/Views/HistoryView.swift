import SwiftUI

struct HistoryView: View {
    @Environment(CommandLog.self) private var log
    @Environment(\.dismiss) private var dismiss
    @State private var controller = ServiceController()
    @State private var expandedID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if log.entries.isEmpty {
                    ContentUnavailableView(
                        "暂无运行记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("执行过启动 / 停止 / 重启 / 状态命令后会记录在这里")
                    )
                } else {
                    List(log.entries) { entry in
                        entryRow(entry)
                    }
                }
            }
            .navigationTitle("运行历史")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("清空") { log.clear() }
                        .disabled(log.entries.isEmpty)
                }
            }
        }
        .frame(width: 620, height: 480)
    }

    private func entryRow(_ entry: CommandEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(entry.succeeded ? .green : .red)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.serviceName)
                        .fontWeight(.medium)
                    Text(entry.command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(entry.timestamp, format: .dateTime.month().day().hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    expandedID = expandedID == entry.id ? nil : entry.id
                } label: {
                    Image(systemName: expandedID == entry.id ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            if expandedID == entry.id {
                Divider()
                ScrollView {
                    Text(entry.outputText.isEmpty ? "（无输出）" : entry.outputText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
                HStack {
                    Text("exit \(entry.exitCode)" + (entry.isTimedOut ? " · 超时" : ""))
                        .font(.caption)
                        .foregroundStyle(entry.succeeded ? .green : .red)
                    Spacer()
                    Button("重跑") {
                        Task {
                            let result = (try? await controller.run(entry.command))
                                ?? CommandResult(exitCode: -1, stdout: "", stderr: "重跑失败")
                            log.record(serviceName: entry.serviceName, command: entry.command, result: result)
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
