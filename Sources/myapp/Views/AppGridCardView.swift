import SwiftUI

/// 参考 macOS 启动台（Launchpad）样式的积木卡片：
/// 无边框、无底色，大图标是绝对主体，名称居中，悬停时才显示柔和底色。
struct AppGridCardView: View {
    let service: ManagedService
    var onSelect: (() -> Void)? = nil
    var isHovering = false

    @Environment(DashboardViewModel.self) private var viewModel

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

    private var statusText: String {
        switch status {
        case .healthy(let ms): "正常 · \(ms)ms"
        case .running: "运行中"
        case .down(let reason): "离线 · \(reason)"
        case .stopped: "未运行"
        case .unknown: "未知"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // 大图标（主体）
            ZStack(alignment: .topLeading) {
                ServiceIconView(service: service, size: 60)
                // 左上角状态点
                Circle()
                    .fill(statusColor)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .offset(x: 4, y: 4)
            }
            .frame(height: 64)

            // 名称（居中）
            Text(service.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            // 状态（小字）
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.gray.opacity(0.12) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { onSelect?() }
    }
}
