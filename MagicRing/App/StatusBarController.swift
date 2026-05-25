import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController {
    private let monitor = PerformanceMonitor(updateInterval: 0.8, historyLimit: 1200)
    private let settings = PanelSettings()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panelSize = NSSize(width: 370, height: 570)
    private let panelCornerRadius: CGFloat = 25

    private let updateChecker = UpdateChecker()

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var hoverPollingTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?
    private var cancellable: AnyCancellable?
    private var isStatusItemHovered = false
    private var isPanelHovered = false
    private var isSettingsMenuVisible = false
    private var isCheckingForUpdates = false

    func start() {
        configureApplicationIcon()
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
        updateCheckTask?.cancel()
        cancellable = nil
        panel?.orderOut(nil)
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
        button.title = " CPU: --%"
        button.toolTip = "MagicRing Performance"
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureApplicationIcon() {
        guard let icon = Self.applicationIcon() else {
            return
        }

        NSApp.applicationIconImage = icon
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
            .background(Color.clear)
        let hostingView = HoverTrackingHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.configureTransparentLayer(cornerRadius: panelCornerRadius)
        hostingView.onMouseEntered = { [weak self] in
            self?.isPanelHovered = true
            self?.hideWorkItem?.cancel()
        }
        hostingView.onMouseExited = { [weak self] in
            self?.isPanelHovered = false
            self?.scheduleHide()
        }

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
        panel.contentView?.layer?.cornerRadius = panelCornerRadius
        panel.contentView?.layer?.masksToBounds = true
        self.panel = panel
    }

    private func updateStatusItem(_ snapshot: PerformanceSnapshot?) {
        guard let button = statusItem.button else {
            return
        }

        let usage = snapshot?.cpuUsage ?? 0
        button.title = " CPU: \(MetricFormatting.percent(usage))"
        button.contentTintColor = .labelColor
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showSettingsMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        guard let panel else {
            return
        }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showSettingsMenu() {
        guard let button = statusItem.button else {
            return
        }

        isSettingsMenuVisible = true
        hidePanel()
        defer {
            isSettingsMenuVisible = false
        }

        let menu = makeSettingsMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    private func makeSettingsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(nativeMenuItem(title: localizedMenuTitle(chinese: "关于 MagicRing", english: "About MagicRing"), action: #selector(handleAboutMenuItem)))
        menu.addItem(nativeMenuItem(title: localizedMenuTitle(chinese: "检查更新...", english: "Check for Updates..."), action: #selector(handleCheckUpdatesMenuItem)))
        menu.addItem(.separator())

        let englishItem = nativeMenuItem(title: "English", action: #selector(handleToggleEnglishMenuItem))
        englishItem.state = settings.isEnglishEnabled ? .on : .off
        menu.addItem(englishItem)

        let launchAtLoginItem = nativeMenuItem(
            title: localizedMenuTitle(chinese: "开机自动启动（建议）", english: "Launch at Login (Recommended)"),
            action: #selector(handleToggleLaunchAtLoginMenuItem)
        )
        launchAtLoginItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = nativeMenuItem(title: localizedMenuTitle(chinese: "退出", english: "Quit"), action: #selector(handleQuitMenuItem))
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        return menu
    }

    private func nativeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func localizedMenuTitle(chinese: String, english: String) -> String {
        settings.isEnglishEnabled ? english : chinese
    }

    @objc private func handleAboutMenuItem() {
        NSApp.activate(ignoringOtherApps: true)

        let info = Bundle.main.infoDictionary
        let marketingVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = info?["CFBundleVersion"] as? String

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "MagicRing",
            .applicationVersion: marketingVersion,
            .credits: NSAttributedString(string: "A compact macOS status bar performance monitor.")
        ]
        if let buildNumber, !buildNumber.isEmpty {
            options[.version] = buildNumber
        }
        if let icon = Self.applicationIcon() {
            options[.applicationIcon] = icon
        }

        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func handleCheckUpdatesMenuItem() {
        performUpdateCheck()
    }

    private func performUpdateCheck() {
        guard !isCheckingForUpdates else {
            return
        }
        isCheckingForUpdates = true

        let checker = updateChecker
        updateCheckTask = Task { @MainActor [weak self] in
            defer { self?.isCheckingForUpdates = false }

            do {
                let result = try await checker.checkForUpdates()
                guard let self else { return }
                self.presentUpdateResult(result)
            } catch {
                guard let self else { return }
                self.presentUpdateError(error)
            }
        }
    }

    private func presentUpdateResult(_ result: UpdateCheckResult) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        if let icon = Self.applicationIcon() {
            alert.icon = icon
        }

        switch result {
        case .upToDate(let currentVersion):
            alert.messageText = localizedMenuTitle(
                chinese: "已是最新版本",
                english: "You're up to date"
            )
            alert.informativeText = localizedMenuTitle(
                chinese: "当前版本 \(currentVersion) 已是最新。",
                english: "MagicRing \(currentVersion) is the latest version available."
            )
            alert.addButton(withTitle: localizedMenuTitle(chinese: "好", english: "OK"))
            _ = runForegroundModal(alert)

        case .updateAvailable(let currentVersion, let latestVersion, let releaseURL, let downloadURL):
            alert.messageText = localizedMenuTitle(
                chinese: "发现新版本",
                english: "A new version is available"
            )
            alert.informativeText = localizedMenuTitle(
                chinese: "最新版本 \(latestVersion) 已发布，当前版本为 \(currentVersion)。",
                english: "MagicRing \(latestVersion) is available. You're currently on \(currentVersion)."
            )
            alert.addButton(withTitle: localizedMenuTitle(chinese: "下载", english: "Download"))
            alert.addButton(withTitle: localizedMenuTitle(chinese: "查看发布说明", english: "Release Notes"))
            alert.addButton(withTitle: localizedMenuTitle(chinese: "稍后", english: "Later"))

            switch runForegroundModal(alert) {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(downloadURL ?? releaseURL)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(releaseURL)
            default:
                break
            }
        }
    }

    private func presentUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedMenuTitle(
            chinese: "无法检查更新",
            english: "Unable to Check for Updates"
        )
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localizedMenuTitle(chinese: "好", english: "OK"))
        alert.addButton(withTitle: localizedMenuTitle(chinese: "在 GitHub 打开", english: "Open on GitHub"))

        if runForegroundModal(alert) == .alertSecondButtonReturn,
           let url = URL(string: "https://github.com/\(UpdateChecker.owner)/\(UpdateChecker.repository)/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Presents an `NSAlert` modally from a menu bar (LSUIElement / `.accessory`) app.
    /// Without temporarily becoming a regular app, the alert window may never
    /// become key, leaving the modal run loop apparently frozen.
    @discardableResult
    private func runForegroundModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        let window = alert.window
        window.level = .modalPanel
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.center()
        window.makeKeyAndOrderFront(nil)

        let response = alert.runModal()

        if previousPolicy != .regular {
            NSApp.setActivationPolicy(previousPolicy)
        }
        return response
    }

    @objc private func handleToggleEnglishMenuItem() {
        settings.isEnglishEnabled.toggle()
    }

    @objc private func handleToggleLaunchAtLoginMenuItem() {
        let desired = !LaunchAtLoginManager.isEnabled
        Task { @MainActor [weak self] in
            do {
                try await LaunchAtLoginManager.setEnabled(desired)
            } catch {
                self?.presentLaunchAtLoginError(error)
            }
        }
    }

    @objc private func handleQuitMenuItem() {
        NSApp.terminate(nil)
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = localizedMenuTitle(chinese: "无法更新开机启动设置", english: "Unable to Update Launch at Login")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedMenuTitle(chinese: "好", english: "OK"))
        runForegroundModal(alert)
    }

    private static func applicationIcon() -> NSImage? {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }

        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
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

        if isHovered, isStatusItemHovered, panel?.isVisible != true, !isSettingsMenuVisible {
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

    private func showPanel() {
        hideWorkItem?.cancel()

        if isSettingsMenuVisible {
            return
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

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureTransparentLayer(cornerRadius: 0)
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTransparentLayer(cornerRadius: 0)
    }

    func configureTransparentLayer(cornerRadius: CGFloat) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = cornerRadius > 0
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparentLayer(cornerRadius: layer?.cornerRadius ?? 0)
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = false
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
