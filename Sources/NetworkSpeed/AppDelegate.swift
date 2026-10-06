import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static private(set) weak var shared: AppDelegate?
    public var openSettingsAction: (() -> Void)?

    private var statusItem: NSStatusItem!
    private var menuBarView: MenuBarView!
    private var statusMenu: NSMenu!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Run as a regular macOS application with Dock icon and native window
        NSApp.setActivationPolicy(.regular)
        
        setupAppMainMenu()
        setupStatusMenu()
        setupStatusItem()
        
        // Start network monitoring & data usage tracker
        NetworkMonitor.shared.start()
        DataUsageTracker.shared.start()
        
        // Always open the main app window on launch unless started with --background
        if CommandLine.arguments.contains("--background") {
            NSApp.setActivationPolicy(.accessory)
        } else if CommandLine.arguments.contains("--show-usage") {
            openDataUsage()
        } else if CommandLine.arguments.contains("--show-settings") {
            openSettings()
        } else {
            openDashboard()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        NetworkMonitor.shared.stop()
        DataUsageTracker.shared.stop()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.show(tab: .dashboard)
        return true
    }
    
    // MARK: - Native macOS Application Menu Bar
    
    private func setupAppMainMenu() {
        let mainMenu = NSMenu()
        
        // 1. App Menu ("Network Speed")
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Network Speed")
        
        let aboutItem = NSMenuItem(title: "About Network Speed", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let hideItem = NSMenuItem(title: "Hide Network Speed", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        let showAllItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Network Speed", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let closeWindowItem = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeWindowItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // 3. View Menu (Navigation shortcuts)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        
        let navDashboard = NSMenuItem(title: "Dashboard", action: #selector(openDashboard), keyEquivalent: "1")
        navDashboard.target = self
        viewMenu.addItem(navDashboard)
        
        let navUsage = NSMenuItem(title: "Network Usage", action: #selector(openDataUsage), keyEquivalent: "2")
        navUsage.target = self
        viewMenu.addItem(navUsage)
        
        let navInterfaces = NSMenuItem(title: "Interfaces", action: #selector(openInterfaces), keyEquivalent: "3")
        navInterfaces.target = self
        viewMenu.addItem(navInterfaces)
        
        let navSettings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "4")
        navSettings.target = self
        viewMenu.addItem(navSettings)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let resetItem = NSMenuItem(title: "Reset Session Stats", action: #selector(resetStats), keyEquivalent: "r")
        resetItem.target = self
        viewMenu.addItem(resetItem)
        
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // 4. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let minimizeItem = NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)
        let zoomItem = NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(zoomItem)
        windowMenu.addItem(NSMenuItem.separator())
        let bringAllItem = NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(bringAllItem)
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Native Status Menu (Reduced, Clean Menu Bar Dropdown)
    
    private func setupStatusMenu() {
        statusMenu = NSMenu()
        statusMenu.delegate = self
    }
    
    // MARK: - Status Item Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = statusMenu
        
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
    }
    
    // MARK: - NSMenuDelegate
    
    public func menuWillOpen(_ menu: NSMenu) {
        updateStatusMenuContents()
    }
    
    private func updateStatusMenuContents() {
        statusMenu.removeAllItems()
        
        let stats = NetworkStats.shared
        let settings = AppSettings.shared
        
        // 1. Live Speed Telemetry (Download & Upload Side-by-Side)
        let downFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.downloadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let upFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.uploadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        
        let speedsItem = NSMenuItem(
            title: "↓ \(downFormatted.fullString)    ↑ \(upFormatted.fullString)",
            action: #selector(openDashboard),
            keyEquivalent: ""
        )
        speedsItem.target = self
        statusMenu.addItem(speedsItem)
        
        // 2. Active Connection
        let connName = stats.activeWiFiSSID ?? stats.activeInterfaceName
        let connItem = NSMenuItem(
            title: "\(stats.activeInterfaceBSD.hasPrefix("en") ? "Wi-Fi" : "Network"): \(connName) (\(stats.localIP))",
            action: #selector(openInterfaces),
            keyEquivalent: ""
        )
        connItem.target = self
        statusMenu.addItem(connItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // 3. Open Network Speed Window
        let openAppItem = NSMenuItem(title: "Open Network Speed…", action: #selector(openDashboard), keyEquivalent: "o")
        openAppItem.target = self
        statusMenu.addItem(openAppItem)
        
        let openSettingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        openSettingsItem.target = self
        statusMenu.addItem(openSettingsItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // 4. Quit
        let quitItem = NSMenuItem(title: "Quit Network Speed", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }
    
    // MARK: - Actions
    
    @objc public func openDashboard() {
        MainWindowController.shared.show(tab: .dashboard)
    }
    
    @objc public func openDataUsage() {
        DataUsageTracker.shared.granularity = .day
        DataUsageTracker.shared.dayOffset = 0
        DataUsageTracker.shared.recalculateSummary()
        MainWindowController.shared.show(tab: .dataUsage)
    }
    
    @objc public func openInterfaces() {
        MainWindowController.shared.show(tab: .interfaces)
    }
    
    @objc public func openSettings() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        if #available(macOS 14.0, *), let action = openSettingsAction {
            action()
        } else {
            NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func openAbout() {
        MainWindowController.shared.show(tab: .about)
    }
    
    public func closePanel() {}
    
    @objc private func copyLocalIP() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(NetworkStats.shared.localIP, forType: .string)
    }
    
    @objc private func toggleMonitoring() {
        AppSettings.shared.isMonitoringEnabled = !AppSettings.shared.isMonitoringEnabled
    }
    
    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? DisplayMode {
            AppSettings.shared.displayMode = mode
        }
    }
    
    @objc private func selectRefreshRate(_ sender: NSMenuItem) {
        if let rate = sender.representedObject as? Double {
            AppSettings.shared.refreshInterval = rate
            NetworkMonitor.shared.updateInterval()
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !LaunchAtLogin.isEnabled
        LaunchAtLogin.isEnabled = newState
        sender.state = newState ? .on : .off
    }
    
    @objc private func resetStats() {
        NetworkStats.shared.resetSession()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
