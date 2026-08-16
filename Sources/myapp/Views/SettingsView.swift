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
            Section("数据") {
                LabeledContent("配置文件", value: ServiceStore.defaultFileURL.path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }
}
