import SwiftUI
import AppKit

public struct InterfacesView: View {
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var isRefreshing: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            SettingsHeroHeader(
                icon: "network",
                color: .blue,
                title: "Interfaces",
                subtitle: "Hardware network adapters, hardware addresses, and telemetry sources on this Mac."
            )
            
            Section {
                if stats.availableInterfaces.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "network.slash")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No network interfaces detected")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(stats.availableInterfaces) { intf in
                        interfaceRow(intf)
                    }
                }
            } header: {
                HStack {
                    Text("Detected Interfaces (\(stats.availableInterfaces.count))")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRefreshing = true
                        }
                        NetworkMonitor.shared.refreshInterfacesList()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation { isRefreshing = false }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? Animation.linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } footer: {
                Text("Select an interface to monitor dedicated adapter throughput, or configure Automatic interface selection in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    @ViewBuilder
    private func interfaceRow(_ intf: InterfaceInfo) -> some View {
        let isCurrentTarget: Bool = {
            if settings.selectedInterface == "auto" {
                return intf.isPrimary
            } else if settings.selectedInterface == "all" {
                return true
            } else {
                return settings.selectedInterface == intf.bsdName
            }
        }()
        
        let iconName: String = {
            let lower = intf.displayName.lowercased()
            if lower.contains("wi-fi") || lower.contains("wifi") || lower.contains("airport") {
                return "wifi"
            } else if lower.contains("ethernet") {
                return "cable.connector"
            } else if lower.contains("thunderbolt") {
                return "bolt.horizontal.fill"
            } else if lower.contains("bridge") {
                return "point.3.connected.trianglepath.dotted"
            } else {
                return "network"
            }
        }()
        
        let iconColor: Color = {
            let lower = intf.displayName.lowercased()
            if lower.contains("wi-fi") || lower.contains("wifi") {
                return .blue
            } else if lower.contains("ethernet") {
                return .orange
            } else if lower.contains("thunderbolt") {
                return .purple
            } else {
                return .teal
            }
        }()
        
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(intf.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        if intf.isPrimary {
                            Text("Primary")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.blue))
                        }
                    }
                    
                    Text("Identifier: \(intf.bsdName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                SettingsIconBadge(systemName: iconName, color: iconColor)
            }
            
            Spacer()
            
            if isCurrentTarget {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .symbolRenderingMode(.hierarchical)
                        .font(.caption.weight(.bold))
                    Text("Active")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.green.opacity(0.12)))
            } else {
                Button("Monitor") {
                    settings.selectedInterface = intf.bsdName
                    NetworkMonitor.shared.updateInterval()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
