import UserNotifications
import Foundation

enum Notifier {
    /// swift run 启动的进程没有 bundle identifier，
    /// 调用 UNUserNotificationCenter.current() 会崩溃，必须跳过。
    private static var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func requestPermission() async {
        guard isBundled else { return }
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func notify(title: String, body: String) async {
        guard isBundled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
