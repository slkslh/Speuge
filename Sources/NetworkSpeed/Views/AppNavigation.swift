import SwiftUI
import AppKit

/// Shared navigation state. Replaces MainWindowController / TabStateObservable.
@MainActor
public final class AppNavigation: ObservableObject {
    public static let shared = AppNavigation()

    @Published public var selectedTab: AppTab = .dashboard

    /// Filled in by the scene bridges (see NetworkSpeedApp.swift).
    var openMainWindow: (() -> Void)?

    private init() {}

    public func show(tab: AppTab = .dashboard) {
        selectedTab = tab
        // AppKit exception: SwiftUI has no API for Dock presence / activation policy.
        NSApp.setActivationPolicy(.regular)
        openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showDataUsage() {
        DataUsageTracker.shared.granularity = .day
        DataUsageTracker.shared.dayOffset = 0
        DataUsageTracker.shared.recalculateSummary()
        show(tab: .dataUsage)
    }

    public func showSettings() {
        show(tab: .settings)
    }
}
