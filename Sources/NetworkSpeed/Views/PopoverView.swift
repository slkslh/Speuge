import SwiftUI
import AppKit

public struct PopoverView: View {
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageTracker = DataUsageTracker.shared
    
    @State private var copiedIP: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Bar with App Icon & Master Switch
            headerBar
            
            Divider()
                .padding(.horizontal, 2)
            
            // Active Connection Card
            activeConnectionCard
            
            // Live Speed Transfer Card
            dataTransferCard
            
            // Live 60s Sparkline Chart
            LiveHistoryChart(
                history: stats.history,
                base: settings.unitBase,
                height: 48,
                showGridLabels: false
            )
            
            // Today's Data Usage Quick Summary
            todayUsageQuickCard
            
            Divider()
                .padding(.horizontal, 2)
            
            // Native Mac Menu Action Buttons
            menuActionsSection
        }
        .padding(14)
        .frame(width: 310, alignment: .top)
        .background(Color.clear)
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIconView(size: 20, showShadow: false)
            
            Text("Network Speed")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Toggle("", isOn: $settings.isMonitoringEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(height: 24)
    }
    
    // MARK: - Active Connection Card
    
    private var activeConnectionCard: some View {
        let isWifi = stats.activeInterfaceBSD.hasPrefix("en")
        let cleanName: String = {
            let raw = stats.activeInterfaceName.trimmingCharacters(in: .whitespaces)
            if !raw.isEmpty && !raw.hasPrefix("<") && raw != "<redacted>" {
                return raw
            }
            return "Wi-Fi"
        }()
        
        return HStack(spacing: 10) {
            Image(systemName: isWifi ? "wifi" : "cable.connector")
                .symbolRenderingMode(.hierarchical)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(cleanName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(stats.localIP, forType: .string)
                    copiedIP = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedIP = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(copiedIP ? "Copied IP" : "IP: \(stats.localIP)")
                            .font(.caption)
                            .monospacedDigit()
                        Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                            .symbolRenderingMode(.hierarchical)
                            .font(.caption2)
                    }
                    .foregroundStyle(copiedIP ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Click to copy local IP address")
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(stats.isConnected && settings.isMonitoringEnabled ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(settings.isMonitoringEnabled ? (stats.isConnected ? "Connected" : "Offline") : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Data Transfer Card
    
    private var dataTransferCard: some View {
        VStack(spacing: 0) {
            speedRow(
                title: "Download",
                symbol: "arrow.down",
                accentColor: Color.blue,
                speed: stats.downloadSpeed,
                peak: stats.peakDownloadSpeed,
                total: stats.sessionDownloadedBytes
            )
            
            Divider()
                .padding(.leading, 42)
                .padding(.trailing, 8)
            
            speedRow(
                title: "Upload",
                symbol: "arrow.up",
                accentColor: Color.orange,
                speed: stats.uploadSpeed,
                peak: stats.peakUploadSpeed,
                total: stats.sessionUploadedBytes
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    private func speedRow(
        title: String,
        symbol: String,
        accentColor: Color,
        speed: Double,
        peak: Double,
        total: UInt64
    ) -> some View {
        let formatted = SpeedFormatter.format(
            bytesPerSecond: speed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let peakFormatted = SpeedFormatter.format(
            bytesPerSecond: peak,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let totalFormatted = SpeedFormatter.formatData(
            bytes: total,
            base: settings.unitBase
        )
        
        return HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.body.weight(.bold))
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("Peak: \(peakFormatted.fullString) • Total: \(totalFormatted)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(settings.isMonitoringEnabled ? formatted.valueString : "--")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(settings.isMonitoringEnabled ? formatted.unitString : "")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
    
    // MARK: - Today Usage Quick Card
    
    private var todayUsageQuickCard: some View {
        Button(action: {
            MainWindowController.shared.show(tab: .dataUsage)
            closePanel()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .symbolRenderingMode(.hierarchical)
                    .font(.body)
                    .foregroundStyle(.purple)
                    .frame(width: 24, height: 24)
                    .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today's Data Usage")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(usageTracker.todayTotalFormatted) • \(usageTracker.todayAppCount) Apps")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(AppleHoverButtonStyle())
    }
    
    // MARK: - Menu Actions Section
    
    private var menuActionsSection: some View {
        VStack(spacing: 2) {
            menuActionButton(title: "Open Network Speed…", icon: "macwindow", shortcut: "⌘D") {
                MainWindowController.shared.show(tab: .dashboard)
                closePanel()
            }
            
            menuActionButton(title: "Data Usage & App Breakdown…", icon: "chart.bar.xaxis", shortcut: "⌘U") {
                MainWindowController.shared.show(tab: .dataUsage)
                closePanel()
            }
            
            menuActionButton(title: "Settings…", icon: "gearshape", shortcut: "⌘,") {
                MainWindowController.shared.show(tab: .settings)
                closePanel()
            }
            
            Divider()
                .padding(.vertical, 2)
            
            menuActionButton(title: "Quit Network Speed", icon: "power", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
        }
    }
    
    private func menuActionButton(
        title: String,
        icon: String,
        shortcut: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppleHoverButtonStyle())
    }
    
    private func closePanel() {
        if let delegate = AppDelegate.shared {
            delegate.closePanel()
        }
    }
}

// MARK: - Apple Hover Button Style

private struct AppleHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}
