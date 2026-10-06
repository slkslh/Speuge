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
