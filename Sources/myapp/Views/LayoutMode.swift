import Foundation

/// 服务展示布局模式
enum LayoutMode: String, CaseIterable, Identifiable {
    case list = "列表"
    case grid = "卡片"

    var id: String { rawValue }

    /// 对应的 SF Symbol 图标
    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }

    /// 切换提示
    var help: String {
        switch self {
        case .list: return "列表模式"
        case .grid: return "卡片模式（积木堆叠）"
        }
    }
}
