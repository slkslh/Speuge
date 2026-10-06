import AppKit
import SwiftUI

/// AppKit is only used here for things SwiftUI cannot do:
/// the custom-drawn status item, its dropdown menu/popover, and the Dock activation policy.
/// The main menu bar is now provided by `AppCommands` (NetworkSpeedApp.swift).
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static private(set) weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var menuBarView: MenuBarView!
    private var customMenu: NSMenu!
    private var isForceQuitting = false

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        setupStatusItem()
        observeWindowClosing()

        NetworkMonitor.shared.start()
        DataUsageTracker.shared.start()

        let arguments = CommandLine.arguments
        if arguments.contains("--background") {
            // The main Window scene opens at launch; close it and hide the Dock icon.
            DispatchQueue.main.async {
                NSApp.windows
                    .filter { $0.styleMask.contains(.titled) }
                    .forEach { $0.close() }
                NSApp.setActivationPolicy(.accessory)
            }
        } else if arguments.contains("--show-usage") {
            AppNavigation.shared.showDataUsage()
            if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
        } else if arguments.contains("--show-settings") {
            DispatchQueue.main.async { AppNavigation.shared.showSettings() }
            if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
        } else {
            AppNavigation.shared.selectedTab = .dashboard
            if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        NetworkMonitor.shared.stop()
        DataUsageTracker.shared.stop()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppNavigation.shared.show(tab: .dashboard)
        if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
        return true
    }

    /// Keep monitoring in the menu bar after the last window closes.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppSettings.shared.keepRunningInMenuBar && !isForceQuitting {
            NSApp.windows
                .filter { $0.styleMask.contains(.titled) }
                .forEach { $0.close() }
            NSApp.setActivationPolicy(.accessory)
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Dock presence

    private func observeWindowClosing() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let closing = note.object as? NSWindow, closing.styleMask.contains(.titled) else { return }
            Task { @MainActor in
                guard AppSettings.shared.showInDockWhenWindowOpen else { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let stillOpen = NSApp.windows.contains {
                    $0.isVisible && $0 !== closing && $0.styleMask.contains(.titled)
                }
                if !stillOpen {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    // MARK: - Status item & Popover

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menuBarView = MenuBarView(statusItem: statusItem)
        menuBarView.translatesAutoresizingMaskIntoConstraints = false

        if let button = statusItem.button {
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(menuBarView)

            NSLayoutConstraint.activate([
                menuBarView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                menuBarView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                menuBarView.topAnchor.constraint(equalTo: button.topAnchor),
                menuBarView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
        
        let hostingController = NSHostingController(rootView: MenuBarPopoverView())
        let size = hostingController.view.fittingSize
        hostingController.view.frame.size = NSSize(width: 260, height: size.height > 0 ? size.height : 210)
        
        let menuItem = NSMenuItem()
        menuItem.view = hostingController.view
        
        customMenu = NSMenu()
        customMenu.addItem(menuItem)
        
        statusItem.menu = customMenu
    }

    public func togglePopover() {
        // AppKit now handles the menu opening and closing automatically
        // via statusItem.menu
    }
    
    public func openPopover() {
        togglePopover()
    }
    
    public func closePopover() {
        customMenu.cancelTracking()
    }

    // MARK: - Actions

    @objc public func openDashboard() {
        AppNavigation.shared.show(tab: .dashboard)
        if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
    }
    
    @objc public func openInterfaces() {
        AppNavigation.shared.show(tab: .interfaces)
        if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
    }
    
    @objc public func openSettings() {
        AppNavigation.shared.showSettings()
        if AppSettings.shared.showInDockWhenWindowOpen { NSApp.setActivationPolicy(.regular) }
    }
    
    @objc public func quitApp() {
        isForceQuitting = true
        NSApp.terminate(nil)
    }
}
