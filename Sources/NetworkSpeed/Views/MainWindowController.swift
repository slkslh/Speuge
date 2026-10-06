import AppKit
import SwiftUI

@MainActor
public final class MainWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = MainWindowController()
    
    private var tabState = TabStateObservable()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Network Speed"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        let toolbar = NSToolbar(identifier: "MainAppToolbar")
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 800, height: 540)
        window.collectionBehavior = [.fullScreenPrimary]
        window.center()
        
        let localState = tabState
        let containerView = NSHostingView(
            rootView: MainWindowContainer(state: localState)
        )
        window.contentView = containerView
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show(tab: AppTab = .dashboard) {
        tabState.selectedTab = tab
        
        // Elevate to regular application with Dock presence
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    public func openTab(_ tab: AppTab) {
        show(tab: tab)
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        // App continues monitoring in menu bar when window is closed
        if AppSettings.shared.showInDockWhenWindowOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let visibleWindows = NSApp.windows.filter { $0.isVisible && $0 != self.window && !($0 is NSPanel) }
                if visibleWindows.isEmpty {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}

// MARK: - Tab State Helper

@MainActor
final class TabStateObservable: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
}

private struct MainWindowContainer: View {
    @ObservedObject var state: TabStateObservable
    
    var body: some View {
        MainAppView(selectedTab: $state.selectedTab)
    }
}
