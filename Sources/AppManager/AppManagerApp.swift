import SwiftUI
import AppKit

@main
struct AppManagerApp: App {
    init() {
        // 从命令行（swift run）启动时，确保窗口能正常获得焦点
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
