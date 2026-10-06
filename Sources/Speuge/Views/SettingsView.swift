import SwiftUI
import AppKit

/// Content of the `Settings` scene (Cmd+,).
public struct SettingsView: View {
    /// Settings scenes size to their content and a grouped Form has no intrinsic width.
    private let pageWidth: CGFloat = 480

    public init() {}

    public var body: some View {
        Form {
            GeneralSettingsSection()
            MenuBarSettingsSection()
            DataSettingsSection()
            
            Section {
                Button("Quit Speuge", role: .destructive) {
                    AppDelegate.shared?.quitApp()
                }
            } header: {
                Text("App Actions")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralSettingsSection: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var isLaunchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Group {
            Section {
                Toggle("Launch at Login", isOn: $isLaunchAtLogin)
                    .toggleStyle(.switch)
                    .onChangeCompat(of: isLaunchAtLogin) { LaunchAtLogin.isEnabled = $0 }

                Toggle("Run in Background", isOn: $settings.keepRunningInMenuBar)
                    .toggleStyle(.switch)

                Toggle("Show in Dock When App is Open", isOn: $settings.showInDockWhenWindowOpen)
                    .toggleStyle(.switch)
                    .onChangeCompat(of: settings.showInDockWhenWindowOpen) { enabled in
                        // AppKit exception: no SwiftUI API for the Dock activation policy.
                        if enabled { NSApp.setActivationPolicy(.regular) }
                    }
            } header: {
                Text("Startup")
            } footer: {
                Text("Control automatic background startup, menu bar persistence, and Dock presence while the window is open.")
            }

            Section {
                Slider(value: $settings.refreshInterval, in: 0.5...2.0, step: 0.5) {
                    Text("Update Frequency")
                } minimumValueLabel: {
                    Text("0.5s")
                } maximumValueLabel: {
                    Text("2.0s")
                }
                .onChangeCompat(of: settings.refreshInterval) { _ in
                    NetworkMonitor.shared.updateInterval()
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                }

                LabeledContent("Current Interval") {
                    Text(String(format: "%.1fs", settings.refreshInterval))
                        .monospacedDigit()
                }
            } header: {
                Text("Monitoring")
            } footer: {
                Text("How often network throughput is sampled.")
            }
        }
    }
}

// MARK: - Menu bar & units

private struct MenuBarSettingsSection: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Group {
            Section {
                Picker("Display Style", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Display Order", selection: $settings.displayOrder) {
                    ForEach(DisplayOrder.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Indicator Glyphs", selection: $settings.arrowStyle) {
                    ForEach(ArrowStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Color Theme", selection: $settings.colorMode) {
                    ForEach(ArrowColorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Monospaced Digits", isOn: $settings.fixedWidthDigits)
                    .toggleStyle(.switch)
            } header: {
                Text("Menu Bar Display")
            } footer: {
                Text("How bandwidth numbers and symbols appear in the menu bar.")
            }

            Section("Units") {
                Picker("Data Unit Standard", selection: $settings.unitBase) {
                    ForEach(UnitBase.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Unit Naming", selection: $settings.unitNaming) {
                    ForEach(UnitNaming.allCases) { Text($0.rawValue).tag($0) }
                }
            }
        }
    }
}

// MARK: - Data

private struct DataSettingsSection: View {
    @ObservedObject private var usageTracker = DataUsageTracker.shared

    private enum ResetTarget {
        case today
        case allHistory
    }

    @State private var resetTarget: ResetTarget = .today
    @State private var showingDialog = false

    var body: some View {
        Group {
            Section {
                Button("Reset Today's Usage…", role: .destructive) {
                    resetTarget = .today
                    showingDialog = true
                }
                Button("Clear All History…", role: .destructive) {
                    resetTarget = .allHistory
                    showingDialog = true
                }
            } header: {
                Text("Data & Storage")
            } footer: {
                Text("Session totals can be reset from the Dashboard.")
            }
        }
        .confirmationDialog(dialogTitle, isPresented: $showingDialog, titleVisibility: .visible) {
            Button(confirmTitle, role: .destructive, action: performReset)
        } message: {
            Text(dialogMessage)
        }
    }

    private var dialogTitle: String {
        switch resetTarget {
        case .today: return String(localized: "Reset Today's Data Usage?")
        case .allHistory: return String(localized: "Clear All Historical Data Usage?")
        }
    }

    private var dialogMessage: String {
        switch resetTarget {
        case .today:
            return String(localized: "This will clear all application bandwidth recorded for today (\(usageTracker.todayTotalFormatted)).")
        case .allHistory:
            return String(localized: "This will permanently delete all stored application bandwidth logs across all dates. This action cannot be undone.")
        }
    }

    private var confirmTitle: String {
        switch resetTarget {
        case .today: return String(localized: "Reset Today")
        case .allHistory: return String(localized: "Clear All History")
        }
    }

    private func performReset() {
        switch resetTarget {
        case .today: usageTracker.resetToday()
        case .allHistory: usageTracker.resetAllHistory()
        }
    }
}
