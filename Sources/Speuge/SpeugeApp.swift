import SwiftUI
import AppKit

@main
public struct SpeugeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    public init() {}

    public var body: some Scene {
        Window("Speuge", id: "main") {
            MainAppView()
                .background {
                    SceneActionsBridge()
                }
        }
        .defaultSize(width: 900, height: 620)
        .commands { AppCommands() }
    }
}

// MARK: - Menu bar commands (replaces the hand-built NSMenu)

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Speuge") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                AppNavigation.shared.showSettings()
            }
            .keyboardShortcut(",")
        }

        CommandGroup(after: .sidebar) {
            Button("Dashboard") { AppNavigation.shared.show(tab: .dashboard) }
                .keyboardShortcut("1")
            Button("Network Usage") { AppNavigation.shared.showDataUsage() }
                .keyboardShortcut("2")
            Button("Interfaces") { AppNavigation.shared.show(tab: .interfaces) }
                .keyboardShortcut("3")
            Button("Settings") { AppNavigation.shared.showSettings() }
                .keyboardShortcut(",")

            Divider()

            Button("Reset Session Stats") { NetworkStats.shared.resetSession() }
                .keyboardShortcut("r")
        }
    }
}

// MARK: - Bridges so AppKit code (status item menu) can open SwiftUI scenes

private struct SceneActionsBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .onAppear {
                AppNavigation.shared.openMainWindow = { openWindow(id: "main") }
            }
    }
}

