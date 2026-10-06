import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case dataUsage = "Network Usage"
    case interfaces = "Interfaces"
    case settings = "Settings"

    public var id: String { rawValue }

    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    public var iconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .dataUsage: return "chart.bar.xaxis"
        case .interfaces: return "network"
        case .settings: return "gearshape"
        }
    }
}

public struct MainAppView: View {
    @ObservedObject private var navigation = AppNavigation.shared
    @ObservedObject private var stats = NetworkStats.shared
    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    private var selection: Binding<AppTab?> {
        Binding(
            get: { navigation.selectedTab },
            set: { if let tab = $0 { navigation.selectedTab = tab } }
        )
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.iconName)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 12) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "speedometer")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Speuge")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("by Shalik Faris")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Version \(version)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            detailView
                .navigationTitle(navigation.selectedTab.title)
        }
        .frame(minWidth: 840, minHeight: 560)
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigation.selectedTab {
        case .dashboard: DashboardView()
        case .dataUsage: DataUsageView()
        case .interfaces: InterfacesView()
        case .settings: SettingsView()
        }
    }


}
