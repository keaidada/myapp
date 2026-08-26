import Foundation

/// 侧边栏"标签/分类"项对应的 SF Symbol 图标。
/// 常见标签/分类映射到贴切的图标，未匹配的用默认图标。
enum SidebarIcons {
    /// 分类 → 图标（Section「服务」下的分类项）
    static func icon(forCategory category: String) -> String {
        switch category.lowercased() {
        case "应用": return "square.stack.3d.up"
        case "开发": return "hammer"
        case "系统", "工具": return "gearshape.2"
        case "网络": return "network"
        default: return "folder"
        }
    }

    /// 标签 → 图标（Section「标签」下的标签项）
    static func icon(forTag tag: String) -> String {
        switch tag.lowercased() {
        case "开发": return "hammer"
        case "效率": return "bolt.fill"
        case "ai": return "brain"
        case "办公": return "briefcase"
        case "娱乐": return "gamecontroller.fill"
        case "影音": return "play.rectangle.fill"
        case "存储": return "internaldrive"
        case "容器": return "shippingbox"
        case "工具": return "wrench.and.screwdriver"
        case "数据库": return "cylinder.split.1x2"
        case "浏览器": return "globe"
        case "游戏": return "gamecontroller"
        case "笔记": return "note.text"
        case "系统": return "gearshape"
        case "编辑器": return "rectangle.and.pencil.and.ellipsis"
        case "网络": return "network"
        case "输入法": return "keyboard"
        case "通讯": return "message"
        case "图片": return "photo"
        case "flowscope": return "flowchart"
        default: return "tag"
        }
    }
}
