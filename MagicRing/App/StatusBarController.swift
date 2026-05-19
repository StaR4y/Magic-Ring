import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController {
    private let monitor = PerformanceMonitor(updateInterval: 0.8, historyLimit: 56)
    private let settings = PanelSettings()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panelSize = NSSize(width: 352, height: 272)
    private let settingsPanelSize = NSSize(width: 390, height: 330)

    private var panel: NSPanel?
    private var settingsPanel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var hoverPollingTask: Task<Void, Never>?
    private var cancellable: AnyCancellable?
    private var isStatusItemHovered = false
    private var isPanelHovered = false

    func start() {
        configureStatusItem()
        configurePanel()
        startStatusItemHoverPolling()
        monitor.start()

        cancellable = monitor.$snapshot.sink { [weak self] snapshot in
            self?.updateStatusItem(snapshot)
        }
    }

    func stop() {
        hideWorkItem?.cancel()
        hoverPollingTask?.cancel()
        cancellable = nil
        panel?.orderOut(nil)
        settingsPanel?.orderOut(nil)
        NSStatusBar.system.removeStatusItem(statusItem)
        monitor.stop()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "MagicRing")
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageLeading
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.title = " --%"
        button.toolTip = "MagicRing Performance"
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let rootView = PerformanceDashboardView(monitor: monitor, settings: settings)
            .padding(12)
        let hostingView = HoverTrackingHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.onMouseEntered = { [weak self] in
            self?.isPanelHovered = true
            self?.hideWorkItem?.cancel()
        }
        hostingView.onMouseExited = { [weak self] in
            self?.isPanelHovered = false
            self?.scheduleHide()
        }

        panel.contentView = hostingView
        self.panel = panel
    }

    private func configureSettingsPanelIfNeeded() -> NSPanel {
        if let settingsPanel {
            return settingsPanel
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: settingsPanelSize),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: true
        )

        panel.title = "MagicRing Settings"
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SettingsView(settings: settings))

        settingsPanel = panel
        return panel
    }

    private func updateStatusItem(_ snapshot: PerformanceSnapshot?) {
        guard let button = statusItem.button else {
            return
        }

        let usage = snapshot?.cpuUsage ?? 0
        button.title = " \(MetricFormatting.percent(usage))"
        button.contentTintColor = .labelColor
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            openSettingsPanel()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        guard let panel else {
            return
        }

        if settingsPanel?.isVisible == true {
            settingsPanel?.orderOut(nil)
            isStatusItemHovered = false
        }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel(dismissingSettingsPanel: true)
        }
    }

    private func openSettingsPanel() {
        hidePanel()

        let panel = configureSettingsPanelIfNeeded()
        if let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let x = min(max(buttonFrame.midX - settingsPanelSize.width / 2, screenFrame.minX + 12), screenFrame.maxX - settingsPanelSize.width - 12)
            let y = max(buttonFrame.minY - settingsPanelSize.height - 10, screenFrame.minY + 12)

            panel.setFrame(NSRect(x: x, y: y, width: settingsPanelSize.width, height: settingsPanelSize.height), display: true)
        } else {
            panel.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func startStatusItemHoverPolling() {
        hoverPollingTask?.cancel()
        hoverPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.updateStatusItemHoverState()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func updateStatusItemHoverState() {
        guard let buttonFrame = statusButtonFrameInScreen() else {
            return
        }

        let isHovered = buttonFrame
            .insetBy(dx: -3, dy: -4)
            .contains(NSEvent.mouseLocation)

        if isHovered, isStatusItemHovered, panel?.isVisible != true, settingsPanel?.isVisible != true {
            showPanel()
            return
        }

        guard isHovered != isStatusItemHovered else {
            return
        }

        isStatusItemHovered = isHovered

        if isHovered {
            showPanel()
        } else {
            scheduleHide()
        }
    }

    private func statusButtonFrameInScreen() -> NSRect? {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            return nil
        }

        return buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showPanel(dismissingSettingsPanel: Bool = false) {
        hideWorkItem?.cancel()

        if settingsPanel?.isVisible == true {
            guard dismissingSettingsPanel else {
                return
            }

            settingsPanel?.orderOut(nil)
        }

        guard let panel,
              let buttonFrame = statusButtonFrameInScreen() else {
            return
        }

        let screenFrame = statusItem.button?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(buttonFrame.midX - panelSize.width / 2, screenFrame.minX + 10), screenFrame.maxX - panelSize.width - 10)
        let y = buttonFrame.minY - panelSize.height - 8

        panel.setFrame(NSRect(x: x, y: max(y, screenFrame.minY + 10), width: panelSize.width, height: panelSize.height), display: true)
        panel.orderFrontRegardless()
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.isStatusItemHovered,
                  !self.isPanelHovered else {
                return
            }

            self.hidePanel()
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: workItem)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }
}

private final class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override var isOpaque: Bool {
        false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
