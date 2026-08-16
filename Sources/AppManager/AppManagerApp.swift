import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
        Task { await Notifier.requestPermission() }
    }
}

@main
struct AppManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: ServiceStore
    @State private var viewModel = DashboardViewModel()

    init() {
        _store = State(initialValue: ServiceStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(viewModel)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 900, height: 600)

        MenuBarExtra("AppManager", systemImage: "square.stack.3d.up") {
            MenuBarView()
                .environment(store)
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }
}
