import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ServiceStore?
    private var log: CommandLog?
    private var quickLaunch: QuickLaunchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
        Task { await Notifier.requestPermission() }
    }

    /// 由主界面 onAppear 注入数据源并启动全局热键
    func configure(store: ServiceStore, commandLog: CommandLog) {
        self.store = store
        self.log = commandLog
        guard quickLaunch == nil else { return }
        let controller = QuickLaunchController(
            storeProvider: { [weak self] in self?.store },
            logProvider: { [weak self] in self?.log }
        )
        controller.startGlobalMonitor()
        quickLaunch = controller
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
                .onAppear {
                    appDelegate.configure(store: store, commandLog: commandLog)
                }
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
