import SwiftUI
import AppKit

@main
public struct NetworkSpeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    public init() {}
    
    public var body: some Scene {
        Settings {
            SettingsView()
                .background {
                    if #available(macOS 14.0, *) {
                        SettingsBridgeView()
                    }
                }
        }
    }
}

@available(macOS 14.0, *)
struct SettingsBridgeView: View {
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        Color.clear
            .onAppear {
                AppDelegate.shared?.openSettingsAction = {
                    openSettings()
                }
            }
    }
}
