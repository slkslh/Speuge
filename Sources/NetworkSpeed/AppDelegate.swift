import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuBarView: MenuBarView!
    private var panel: MenuBarExtraPanel!
    private var contextMenu: NSMenu!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon completely (accessory menu bar app)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPanel()
        setupContextMenu()
        
        // Start network monitoring
        NetworkMonitor.shared.start()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        NetworkMonitor.shared.stop()
    }
    
    // MARK: - Status Item Setup
    
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
            
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    // MARK: - Native Panel Setup
    
    private func setupPanel() {
        panel = MenuBarExtraPanel()
        panel.onClose = { [weak self] in
            self?.statusItem.button?.isHighlighted = false
            self?.menuBarView.needsDisplay = true
        }
    }
    
    // MARK: - Context Menu Setup
    
    private func setupContextMenu() {
        contextMenu = NSMenu()
        
        let headerItem = NSMenuItem(title: "Network Speed Monitor", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        contextMenu.addItem(headerItem)
        contextMenu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "Open Dashboard…", action: #selector(openDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        contextMenu.addItem(dashboardItem)
        
        let resetItem = NSMenuItem(title: "Reset Session Stats", action: #selector(resetStats), keyEquivalent: "r")
        resetItem.target = self
        contextMenu.addItem(resetItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        // Style Submenu
        let styleMenuItem = NSMenuItem(title: "Display Style", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            styleSubmenu.addItem(item)
        }
        styleMenuItem.submenu = styleSubmenu
        contextMenu.addItem(styleMenuItem)
        
        // Refresh rate submenu
        let rateMenuItem = NSMenuItem(title: "Update Frequency", action: nil, keyEquivalent: "")
        let rateSubmenu = NSMenu()
        let rates: [(String, Double)] = [("0.5s (Fast)", 0.5), ("1.0s (Normal)", 1.0), ("2.0s (Eco)", 2.0)]
        for (label, interval) in rates {
            let item = NSMenuItem(title: label, action: #selector(selectRefreshRate(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            rateSubmenu.addItem(item)
        }
        rateMenuItem.submenu = rateSubmenu
        contextMenu.addItem(rateMenuItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        contextMenu.addItem(loginItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Network Speed", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            // Right click: show context menu
            if panel.isVisible {
                panel.closePanel()
            }
            updateContextMenuCheckmarks()
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            // Detach menu after opening so left click works again
            statusItem.menu = nil
        } else {
            // Left click: toggle floating panel
            togglePanel(sender)
        }
    }
    
    @objc private func openDashboard() {
        if let button = statusItem.button {
            panel.show(attachedTo: button)
            menuBarView.needsDisplay = true
        }
    }
    
    private func togglePanel(_ sender: NSStatusBarButton) {
        if panel.isVisible {
            panel.closePanel()
            sender.isHighlighted = false
            menuBarView.needsDisplay = true
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.show(attachedTo: sender)
            menuBarView.needsDisplay = true
        }
    }
    
    private func updateContextMenuCheckmarks() {
        let currentMode = AppSettings.shared.displayMode
        if let styleItem = contextMenu.item(withTitle: "Display Style"), let submenu = styleItem.submenu {
            for item in submenu.items {
                if let mode = item.representedObject as? DisplayMode {
                    item.state = (mode == currentMode) ? .on : .off
                }
            }
        }
        
        let currentRate = AppSettings.shared.refreshInterval
        if let rateItem = contextMenu.item(withTitle: "Update Frequency"), let submenu = rateItem.submenu {
            for item in submenu.items {
                if let rate = item.representedObject as? Double {
                    item.state = (abs(rate - currentRate) < 0.1) ? .on : .off
                }
            }
        }
        
        if let loginItem = contextMenu.item(withTitle: "Launch at Login") {
            loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        }
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
