import SwiftUI
import AppKit

@main
struct AppManagerApp: App {
    @State private var store: ServiceStore

    init() {
        // 从命令行（swift run）启动时，确保窗口能正常获得焦点
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        _store = State(initialValue: ServiceStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
