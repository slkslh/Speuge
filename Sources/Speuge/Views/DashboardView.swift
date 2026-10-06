import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject private var stats = NetworkStats.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var copiedIP = false
    @State private var showingResetDialog = false

    public init() {}

    public var body: some View {
        Form {
            HStack(alignment: .top, spacing: 16) {
                directionGroupBox(
                    title: "Download", symbol: "arrow.down", tint: Semantic.download,
                    speed: stats.downloadSpeed, peak: stats.peakDownloadSpeed, total: stats.sessionDownloadedBytes
                )
                
                directionGroupBox(
                    title: "Upload", symbol: "arrow.up", tint: Semantic.upload,
                    speed: stats.uploadSpeed, peak: stats.peakUploadSpeed, total: stats.sessionUploadedBytes
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.bottom, 8)

            Section("Network Activity") {
                LiveHistoryChart(history: stats.history, base: settings.unitBase)
            }

            Section("Connection") {
                LabeledContent("Status", value: statusText)

                LabeledContent("Active Interface") {
                    Text("\(stats.activeInterfaceName) (\(stats.activeInterfaceBSD))")
                        .monospacedDigit()
                }

                LabeledContent("Local IP Address") {
                    HStack {
                        Text(stats.localIP)
                            .monospacedDigit()
                            .textSelection(.enabled)
                        Button(action: copyLocalIP) {
                            Label("Copy IP Address", systemImage: copiedIP ? "checkmark" : "doc.on.doc")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Copy IP address")
                    }
                }

                LabeledContent("Gateway Router") {
                    Text(stats.gatewayIP).monospacedDigit()
                }

                LabeledContent("Session Duration") {
                    Text(stats.sessionStartTime, style: .timer).monospacedDigit()
                }
            }

            Section {
                Button("Reset Session…", role: .destructive) {
                    showingResetDialog = true
                }
            } footer: {
                Text("Resets this session's totals and peak speeds. Recorded data usage is not affected.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset Session Statistics?", isPresented: $showingResetDialog, titleVisibility: .visible) {
            Button("Reset Session", role: .destructive) { stats.resetSession() }
        } message: {
            Text("This will reset current session totals and peak speeds to zero. Historical data usage will not be affected.")
        }
    }

    // MARK: - Sections

    private func directionGroupBox(
        title: LocalizedStringKey,
        symbol: String,
        tint: Color,
        speed: Double,
        peak: Double,
        total: UInt64
    ) -> some View {
        let current = SpeedFormatter.format(bytesPerSecond: speed, base: settings.unitBase, naming: settings.unitNaming)
        let peakValue = SpeedFormatter.format(bytesPerSecond: peak, base: settings.unitBase, naming: settings.unitNaming)

        return GroupBox {
            VStack(spacing: 8) {
                LabeledContent("Current") {
                    Text(settings.isMonitoringEnabled ? current.fullString : "--")
                        .font(.title3)
                        .monospacedDigit()
                }
                Divider()
                LabeledContent("Peak") {
                    Text(peakValue.fullString).monospacedDigit()
                }
                Divider()
                LabeledContent("Session Total") {
                    Text(SpeedFormatter.formatData(bytes: total, base: settings.unitBase)).monospacedDigit()
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        } label: {
            TintedLabel(title: title, systemImage: symbol, tint: tint)
        }
    }

    private var statusText: String {
        if !settings.isMonitoringEnabled { return String(localized: "Paused") }
        return stats.isConnected ? String(localized: "Connected") : String(localized: "Offline")
    }

    private func copyLocalIP() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stats.localIP, forType: .string)
        copiedIP = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedIP = false
        }
    }
}
