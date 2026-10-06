import SwiftUI
import AppKit

public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case dataUsage = "Network Usage"
    case interfaces = "Interfaces"
    case settings = "General"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .dataUsage: return "chart.bar.xaxis"
        case .interfaces: return "network"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .dashboard: return .blue
        case .dataUsage: return .orange
        case .interfaces: return .teal
        case .settings: return .gray
        case .about: return .indigo
        }
    }
}

public struct MainAppView: View {
    @Binding public var selectedTab: AppTab
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var searchText: String = ""
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    
    public init(selectedTab: Binding<AppTab>) {
        self._selectedTab = selectedTab
    }
    
    private var filteredTelemetryTabs: [AppTab] {
        let base: [AppTab] = [.dashboard, .dataUsage, .interfaces]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return base
        }
        return base.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredSystemTabs: [AppTab] {
        let base: [AppTab] = [.about]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return base
        }
        return base.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            sidebarView
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        telemetryToolbarItem
                    }
                }
        }
        .frame(minWidth: 840, minHeight: 560)
    }
    
    // MARK: - Native Sidebar (HIG List)
    
    private var sidebarView: some View {
        List(selection: Binding<AppTab?>(
            get: { selectedTab },
            set: { if let tab = $0 { selectedTab = tab } }
        )) {
            if !filteredTelemetryTabs.isEmpty {
                Section("Telemetry") {
                    ForEach(filteredTelemetryTabs) { tab in
                        NavigationLink(value: tab) {
                            Label {
                                Text(tab.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: tab.iconName)
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.body)
                                    .foregroundStyle(tab.iconColor)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
            
            if !filteredSystemTabs.isEmpty {
                Section("System") {
                    ForEach(filteredSystemTabs) { tab in
                        NavigationLink(value: tab) {
                            Label {
                                Text(tab.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: tab.iconName)
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.body)
                                    .foregroundStyle(tab.iconColor)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            sidebarBottomBar
        }
    }
    
    private var sidebarBottomBar: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(stats.isConnected && settings.isMonitoringEnabled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(stats.isConnected ? (stats.activeWiFiSSID ?? stats.activeInterfaceName) : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Toggle("", isOn: $settings.isMonitoringEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Detail Content Area
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .dataUsage:
            DataUsageView(embeddedInMainApp: true)
        case .interfaces:
            InterfacesView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
    
    // MARK: - Toolbar Telemetry Pill
    
    private var telemetryToolbarItem: some View {
        let downFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.downloadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let upFormatted = SpeedFormatter.format(
            bytesPerSecond: stats.uploadSpeed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                Text(downFormatted.fullString)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            
            Divider()
                .frame(height: 12)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text(upFormatted.fullString)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}
