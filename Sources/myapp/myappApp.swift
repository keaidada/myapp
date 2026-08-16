import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
        Task { await Notifier.requestPermission() }
    }
}

@main
struct myappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: ServiceStore
    @State private var viewModel = DashboardViewModel()
    @State private var commandLog = CommandLog()

    init() {
        _store = State(initialValue: ServiceStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(viewModel)
                .environment(commandLog)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 900, height: 600)

        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .environment(viewModel)
                .environment(commandLog)
        } label: {
            MenuBarIcon()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }
}
