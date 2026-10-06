import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var usageTracker = DataUsageTracker.shared
    
    @State private var isLaunchAtLogin = LaunchAtLogin.isEnabled
    @State private var showingResetAlert = false
    @State private var resetTarget: ResetTarget = .today
    
    enum ResetTarget {
        case session
        case today
        case allHistory
    }
    
    public init() {}
    
    public var body: some View {
        Form {
            SettingsHeroHeader(
                icon: "gearshape.fill",
                color: .gray,
                title: "General",
                subtitle: "Configure menu bar indicators, display telemetry, update frequency, and system startup preferences."
            )
            
            // Group 1: Menu Bar Display
            Section {
                Picker(selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                } label: {
                    Label("Display Style", badge: "macwindow", color: .blue)
                }
                .pickerStyle(.menu)
                
                Picker(selection: $settings.displayOrder) {
                    ForEach(DisplayOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                } label: {
                    Label("Display Order", badge: "arrow.up.arrow.down", color: .teal)
                }
                .pickerStyle(.menu)
                
                Picker(selection: $settings.arrowStyle) {
                    ForEach(ArrowStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                } label: {
                    Label("Indicator Glyphs", badge: "character.textbox", color: .indigo)
                }
                .pickerStyle(.menu)
                
                Picker(selection: $settings.colorMode) {
                    ForEach(ArrowColorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                } label: {
                    Label("Color Theme", badge: "paintpalette.fill", color: .purple)
                }
                .pickerStyle(.menu)
                
                Toggle(isOn: $settings.fixedWidthDigits) {
                    Label("Monospaced Digits", badge: "number.square.fill", color: .orange)
                }
                .toggleStyle(.switch)
            } header: {
                Text("Menu Bar Display")
                    .font(.headline)
            } footer: {
                Text("Configure how bandwidth numbers and symbols appear in the macOS menu bar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Group 2: Monitoring & Refresh
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Update Frequency", badge: "timer", color: .green)
                        Spacer()
                        Text(String(format: "%.1fs", settings.refreshInterval))
                            .font(.body)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: $settings.refreshInterval,
                        in: 0.5...2.0,
                        step: 0.5
                    ) {
                        Text("Update Frequency")
                    } minimumValueLabel: {
                        Text("0.5s")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("2.0s")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: settings.refreshInterval) { _ in
                        NetworkMonitor.shared.updateInterval()
                    }
                }
                .padding(.vertical, 4)
                
                Picker(selection: $settings.unitBase) {
                    ForEach(UnitBase.allCases) { base in
                        Text(base.rawValue).tag(base)
                    }
                } label: {
                    Label("Data Unit Standard", badge: "scalemass.fill", color: .cyan)
                }
                .pickerStyle(.menu)
                
                Picker(selection: $settings.unitNaming) {
                    ForEach(UnitNaming.allCases) { naming in
                        Text(naming.rawValue).tag(naming)
                    }
                } label: {
                    Label("Unit Naming Convention", badge: "textformat.size", color: .blue)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Monitoring & Units")
                    .font(.headline)
            } footer: {
                Text("Sampling rate for network socket telemetry and data unit standard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Group 3: System & Integration
            Section {
                Toggle(isOn: $isLaunchAtLogin) {
                    Label("Launch at Login", badge: "arrow.turn.right.up", color: .yellow)
                }
                .toggleStyle(.switch)
                .onChange(of: isLaunchAtLogin) { val in
                    LaunchAtLogin.isEnabled = val
                }
                
                Toggle(isOn: $settings.showInDockWhenWindowOpen) {
                    Label("Show in Dock When App is Open", badge: "dock.rectangle", color: .pink)
                }
                .toggleStyle(.switch)
                .onChange(of: settings.showInDockWhenWindowOpen) { val in
                    if val {
                        NSApp.setActivationPolicy(.regular)
                    }
                }
            } header: {
                Text("System & Startup")
                    .font(.headline)
            } footer: {
                Text("Control automatic background startup and Dock presence while the window is active.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Group 4: Data & Storage
            Section {
                HStack {
                    Label("Reset Session Speed Totals", badge: "arrow.counterclockwise.circle.fill", color: .orange)
                    Spacer()
                    Button("Reset Session") {
                        resetTarget = .session
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Label("Reset Today's Recorded Usage", badge: "clock.arrow.circlepath", color: .blue)
                    Spacer()
                    Button("Reset Today") {
                        resetTarget = .today
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Label("Clear All Historical Data Usage", badge: "trash.fill", color: .red)
                    Spacer()
                    Button(role: .destructive) {
                        resetTarget = .allHistory
                        showingResetAlert = true
                    } label: {
                        Text("Clear All History")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } header: {
                Text("Data & Storage")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .alert(alertTitle, isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button(alertConfirmButtonText, role: .destructive) {
                performReset()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Reset Alert Logic
    
    private var alertTitle: String {
        switch resetTarget {
        case .session: return "Reset Session Statistics?"
        case .today: return "Reset Today's Data Usage?"
        case .allHistory: return "Clear All Historical Data Usage?"
        }
    }
    
    private var alertMessage: String {
        switch resetTarget {
        case .session: return "This will reset current session throughput counters and peak speed values to zero."
        case .today: return "This will clear all application bandwidth recorded for today (\(usageTracker.todayTotalFormatted))."
        case .allHistory: return "This will permanently delete all stored application bandwidth logs across all dates. This action cannot be undone."
        }
    }
    
    private var alertConfirmButtonText: String {
        switch resetTarget {
        case .session: return "Reset Session"
        case .today: return "Reset Today"
        case .allHistory: return "Clear All History"
        }
    }
    
    private func performReset() {
        switch resetTarget {
        case .session:
            stats.resetSession()
        case .today:
            usageTracker.resetToday()
        case .allHistory:
            usageTracker.resetAllHistory()
        }
    }
}
