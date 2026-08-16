import SwiftUI

struct CommandOutputView: View {
    let result: CommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.exitCode == 0 ? "完成" : "失败（exit \(result.exitCode)）")
                    .font(.headline)
                    .foregroundStyle(result.exitCode == 0 ? .green : .red)
                if result.isTimedOut { Text("超时").foregroundStyle(.orange) }
                Spacer()
            }
            ScrollView {
                Text(result.stdout + result.stderr)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 160, maxHeight: 300)
        }
        .padding()
        .frame(width: 560)
    }
}
