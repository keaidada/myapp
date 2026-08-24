import AppKit
import Observation
import SwiftUI

/// 可接收键盘输入的非激活浮动面板
final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
@Observable
final class QuickLaunchController {
    var query = ""
    var selectedIndex = 0
    private(set) var isVisible = false

    private let storeProvider: () -> ServiceStore?
    private let logProvider: () -> CommandLog?
    private var panel: QuickPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    static let hotKeyCode: UInt16 = 46 // M

    init(storeProvider: @escaping () -> ServiceStore?, logProvider: @escaping () -> CommandLog?) {
        self.storeProvider = storeProvider
        self.logProvider = logProvider
    }

    var results: [ManagedService] {
        guard let store = storeProvider() else { return [] }
        return QuickLaunchMatcher.ranked(store.services, query: query)
    }

    /// 注册全局热键 Cmd+Shift+M
    func startGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.hotKeyCode,
                  event.modifierFlags.contains(.command),
                  event.modifierFlags.contains(.shift) else { return }
            DispatchQueue.main.async {
                self?.toggle()
            }
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard !isVisible else { return }
        query = ""
        selectedIndex = 0

        let view = QuickLaunchView(controller: self)
        let hosting = NSHostingController(rootView: view)

        let panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hosting
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // 拦截上下键 / Esc
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Esc
                self.hide()
                return nil
            case 126: // ↑
                self.moveSelection(-1)
                return nil
            case 125: // ↓
                self.moveSelection(1)
                return nil
            default:
                return event
            }
        }

        isVisible = true
        // 聚焦输入框
        DispatchQueue.main.async { [weak hosting] in
            hosting?.view.window?.makeFirstResponder(hosting?.view)
        }
    }

    func hide() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }

    func moveSelection(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    /// 启动当前选中的服务
    func launchSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        launch(results[selectedIndex])
    }

    /// 启动指定服务并关闭面板
    func launch(_ service: ManagedService) {
        let controller = ServiceController()
        let logText = CommandLogging.launchCommandText(for: service)
        Task {
            let result = (try? await controller.launch(service))
                ?? CommandResult(exitCode: -1, stdout: "", stderr: "启动失败")
            if result.exitCode == 0 {
                storeProvider()?.recordLaunch(service.id)
            }
            if let log = logProvider() {
                log.record(serviceName: service.name, command: logText, result: result)
            }
        }
        hide()
    }
}
