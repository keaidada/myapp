import Foundation

enum CommandLogging {
    /// 生成服务启动命令的日志展示文本
    static func launchCommandText(for service: ManagedService) -> String {
        switch service.kind {
        case .app: return service.appPath ?? service.name
        case .url: return service.url ?? service.name
        case .command: return service.command ?? service.name
        }
    }
}
