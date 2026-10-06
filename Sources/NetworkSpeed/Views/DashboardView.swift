import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var copiedIP = false
    @State private var showingResetAlert = false
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // Major Section Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Real-time network throughput, session telemetry, and active hardware connection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                
                // Hero Speed Cards (Download & Upload Side-by-Side)
                heroSpeedCards
                
                // 60-Second Activity Chart Card
                chartSection
                
                // Connection & Telemetry Inset Grouped Card
                connectionDetailsCard
            }
            .padding(20)
        }
        .alert("Reset Session Statistics?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Session", role: .destructive) {
                stats.resetSession()
            }
        } message: {
            Text("This will reset current session totals and peak speeds to zero. Historical data usage will not be affected.")
        }
    }
    
    // MARK: - Hero Speed Cards (Side-by-Side)
    
    private var heroSpeedCards: some View {
        let downFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.downloadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let downPeak = SpeedFormatter.format(
            bytesPerSecond: stats.peakDownloadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let downTotal = SpeedFormatter.formatData(
            bytes: stats.sessionDownloadedBytes,
            base: settings.unitBase
        )
        
        let upFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.uploadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let upPeak = SpeedFormatter.format(
            bytesPerSecond: stats.peakUploadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let upTotal = SpeedFormatter.formatData(
            bytes: stats.sessionUploadedBytes,
            base: settings.unitBase
        )
        
        return HStack(spacing: 16) {
            speedCard(
                title: "Download",
                icon: "arrow.down",
                accentColor: Color.blue,
                valueString: settings.isMonitoringEnabled ? downFormatted.valueString : "--",
                unitString: settings.isMonitoringEnabled ? downFormatted.unitString : "",
                peakString: downPeak.fullString,
                totalString: downTotal
            )
            
            speedCard(
                title: "Upload",
                icon: "arrow.up",
                accentColor: Color.orange,
                valueString: settings.isMonitoringEnabled ? upFormatted.valueString : "--",
                unitString: settings.isMonitoringEnabled ? upFormatted.unitString : "",
                peakString: upPeak.fullString,
                totalString: upTotal
            )
        }
    }
    
    private func speedCard(
        title: String,
        icon: String,
        accentColor: Color,
        valueString: String,
        unitString: String,
        peakString: String,
        totalString: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 24, height: 24)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(valueString)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Text(unitString)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(height: 32)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PEAK")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(peakString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SESSION TOTAL")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(totalString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Live Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Activity")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            
            VStack(spacing: 0) {
                LiveHistoryChart(
                    history: stats.history,
                    base: settings.unitBase,
                    height: 120,
                    showGridLabels: true
                )
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Connection Details Card
    
    private var connectionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connection & Telemetry")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                
                Spacer()
                
                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .symbolRenderingMode(.hierarchical)
                        Text("Reset Session")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(spacing: 0) {
                // Active Interface row
                connectionRow(
                    icon: stats.activeInterfaceBSD.hasPrefix("en") ? "wifi" : "cable.connector",
                    iconColor: .blue,
                    title: "Active Interface",
                    subtitle: "Default network routing adapter"
                ) {
                    Text("\(stats.activeInterfaceName) (\(stats.activeInterfaceBSD))")
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                Divider().padding(.leading, 48)
                
                // Local IP Row (with copy action)
                connectionRow(
                    icon: "network",
                    iconColor: .purple,
                    title: "Local IP Address",
                    subtitle: "Assigned IPv4 address on local subnet"
                ) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(stats.localIP, forType: .string)
                        copiedIP = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedIP = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(copiedIP ? "Copied!" : stats.localIP)
                                .font(.body)
                                .monospacedDigit()
                            Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                                .symbolRenderingMode(.hierarchical)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Divider().padding(.leading, 48)
                
                // Gateway IP Row
                connectionRow(
                    icon: "server.rack",
                    iconColor: .teal,
                    title: "Gateway Router",
                    subtitle: "Default router uplink IP"
                ) {
                    Text(stats.gatewayIP)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                Divider().padding(.leading, 48)
                
                // Session Uptime Row
                connectionRow(
                    icon: "clock",
                    iconColor: .indigo,
                    title: "Session Duration",
                    subtitle: "Elapsed monitoring uptime"
                ) {
                    Text(sessionDurationString)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func connectionRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private var sessionDurationString: String {
        let elapsed = max(0, Int(Date().timeIntervalSince(stats.sessionStartTime)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%02dm %02ds", minutes, seconds)
        }
    }
}
