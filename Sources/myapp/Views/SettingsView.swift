import SwiftUI

struct SettingsView: View {
    @Environment(DashboardViewModel.self) private var viewModel

    var body: some View {
        Form {
            Section("监控") {
                Stepper(
                    "轮询间隔：\(Int(viewModel.pollInterval)) 秒",
                    value: Binding(
                        get: { viewModel.pollInterval },
                        set: { viewModel.pollInterval = $0 }
                    ),
                    in: 5...120,
                    step: 5
                )
            }
            Section("通知") {
                Toggle(
                    "服务离线时通知",
                    isOn: Binding(
                        get: { viewModel.notifyOnDown },
                        set: { viewModel.notifyOnDown = $0 }
                    )
                )
            }
            Section("自动唤醒（服务挂了自动拉起）") {
                Toggle(
                    "启用自动唤醒",
                    isOn: Binding(
                        get: { viewModel.autoRestartEnabled },
                        set: { viewModel.autoRestartEnabled = $0 }
                    )
                )
                Stepper(
                    "最大重试次数：\(viewModel.autoRestartMaxAttempts)",
                    value: Binding(
                        get: { viewModel.autoRestartMaxAttempts },
                        set: { viewModel.autoRestartMaxAttempts = $0 }
                    ),
                    in: 1...10,
                    step: 1
                )
                .disabled(!viewModel.autoRestartEnabled)
                Stepper(
                    "重试间隔：\(Int(viewModel.autoRestartInterval)) 秒",
                    value: Binding(
                        get: { viewModel.autoRestartInterval },
                        set: { viewModel.autoRestartInterval = $0 }
                    ),
                    in: 10...300,
                    step: 10
                )
                .disabled(!viewModel.autoRestartEnabled)
                Text("仅对配置了健康检查地址的命令类服务生效；应用类不会自动启动")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("数据") {
                LabeledContent("配置文件", value: ServiceStore.defaultFileURL.path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
