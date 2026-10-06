import SwiftUI

public struct InterfacesView: View {
    @ObservedObject private var stats = NetworkStats.shared
    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                if stats.availableInterfaces.isEmpty {
                    EmptyStateView(
                        title: "No Network Interfaces",
                        systemImage: "network.slash",
                        message: "No network adapters were detected on this Mac."
                    )
                } else {
                    ForEach(stats.availableInterfaces) { interface in
                        interfaceRow(interface)
                    }
                }
            } header: {
                Text("Detected Interfaces (\(stats.availableInterfaces.count))")
            } footer: {
                Text("Choose Monitor to track a single adapter. Automatic and All Interfaces are available from the Network Usage toolbar.")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NetworkMonitor.shared.refreshInterfacesList()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh interface list")
            }
        }
    }

    private func isCurrentTarget(_ interface: InterfaceInfo) -> Bool {
        switch settings.selectedInterface {
        case "auto": return interface.isPrimary
        case "all": return true
        default: return settings.selectedInterface == interface.bsdName
        }
    }

    private func symbol(for interface: InterfaceInfo) -> String {
        let name = interface.displayName.lowercased()
        if name.contains("wi-fi") || name.contains("wifi") || name.contains("airport") { return "wifi" }
        if name.contains("ethernet") { return "cable.connector" }
        if name.contains("thunderbolt") { return "bolt.horizontal" }
        if name.contains("bridge") { return "point.3.connected.trianglepath.dotted" }
        return "network"
    }

    private func interfaceRow(_ interface: InterfaceInfo) -> some View {
        LabeledContent {
            if isCurrentTarget(interface) {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Monitor") {
                    settings.selectedInterface = interface.bsdName
                    NetworkMonitor.shared.updateInterval()
                }
            }
        } label: {
            Label {
                VStack(alignment: .leading) {
                    HStack {
                        Text(interface.displayName)
                        if interface.isPrimary {
                            Text("Primary")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Identifier: \(interface.bsdName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol(for: interface))
            }
        }
    }
}
