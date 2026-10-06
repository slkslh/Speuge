import SwiftUI
import Charts

/// Values SwiftUI/Charts cannot infer. Defined once.
private enum Metrics {
    /// Charts have no intrinsic height inside a Form.
    static let chartHeight: CGFloat = 140
    /// Matches the app-icon size used in Finder-style lists.
    static let appIcon: CGFloat = 28
}

public struct DataUsageView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            UsageOverview()
                .navigationDestination(for: String.self) { appId in
                    AppUsageDetail(appId: appId)
                }
        }
    }
}

// MARK: - Filter Headers (shared by overview and app detail)

private struct UsageFiltersHeader: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var tracker = DataUsageTracker.shared
    
    var body: some View {
        Section {
            Picker("Device", selection: $settings.selectedInterface) {
                Text("All Devices").tag("all")
                Text("Auto (Primary)").tag("auto")
                Divider()
                ForEach(stats.availableInterfaces) { interface in
                    Text(interface.displayName).tag(interface.bsdName)
                }
            }
            .onChangeCompat(of: settings.selectedInterface) { _ in
                NetworkMonitor.shared.updateInterval()
            }
        }
        
        HStack {
            Picker(selection: $tracker.granularity, label: EmptyView()) {
                ForEach([UsageGranularity.day, UsageGranularity.week]) { granularity in
                    Text(granularity.rawValue).tag(granularity)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

private struct UsageNavigationHeader: View {
    @ObservedObject var tracker = DataUsageTracker.shared
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            ControlGroup {
                Button {
                    tracker.goToPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!tracker.canGoBack)
                
                Button {
                    tracker.goToCurrent()
                } label: {
                    Text(tracker.screenTimeSummary.headerNavTitle)
                        .frame(width: 140)
                        .lineLimit(1)
                }
                
                Button {
                    tracker.goToNext()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!tracker.canGoForward)
            }
            .fixedSize()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
    }
}

// MARK: - Overview

private struct UsageOverview: View {
    @ObservedObject private var tracker = DataUsageTracker.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let summary = tracker.screenTimeSummary
        let base = settings.unitBase

        Form {
            UsageFiltersHeader()
            UsageNavigationHeader(title: "Network Usage")
            
            Section {
                LabeledContent(summary.cardSubtitle) {
                    Text(summary.mainValueFormatted)
                        .font(.title)
                        .monospacedDigit()
                }
                if let trend = summary.trendText {
                    LabeledContent("Trend") {
                        Label(trend, systemImage: summary.trendIsUp == true ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                UsageBarChart(
                    bars: summary.weekDays,
                    average: summary.dailyAverageBytes,
                    base: base,
                    highlightSelection: tracker.granularity == .day,
                    onSelect: { tracker.selectDay(date: $0) }
                )

                if tracker.granularity == .day {
                    HourlyChart(hourly: summary.hourlyUsage, base: base)
                }
            }

            Section {
                DirectionRows(
                    bytesIn: summary.totalBytesIn,
                    bytesOut: summary.totalBytesOut,
                    base: base
                )
                LabeledContent("Total Network Usage") {
                    Text(SpeedFormatter.formatData(bytes: summary.totalBytes, base: base))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            } footer: {
                Text(summary.lastUpdatedString)
            }

            Section("Most Used") {
                if summary.topApps.isEmpty {
                    EmptyStateView(
                        title: "No App Activity Logged",
                        systemImage: "app.badge.checkmark",
                        message: "Network usage from applications is tracked here automatically."
                    )
                } else {
                    ForEach(summary.topApps.prefix(30)) { app in
                        NavigationLink(value: app.id) {
                            AppUsageRow(item: app, base: base)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .searchable(text: $tracker.searchQuery, prompt: "Search Apps")
        .navigationTitle("Network Usage")
    }
}

// MARK: - App detail (pushed; back button is provided by NavigationStack)

private struct AppUsageDetail: View {
    let appId: String

    @ObservedObject private var tracker = DataUsageTracker.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let detail = tracker.getAppDetail(appId: appId)
        let base = settings.unitBase
        let icon = AppInfoResolver.shared.icon(for: appId, bundlePath: detail.bundlePath, displayName: detail.displayName)

        Form {
            UsageFiltersHeader()
            UsageNavigationHeader(title: detail.displayName)
            
            Section {
                Label {
                    Text(detail.displayName).font(.headline)
                } icon: {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Metrics.appIcon, height: Metrics.appIcon)
                }
            }

            Section {
                LabeledContent(tracker.granularity == .day ? tracker.screenTimeSummary.cardSubtitle : "Total Usage") {
                    Text(SpeedFormatter.formatData(bytes: detail.totalBytes, base: base))
                        .font(.title)
                        .monospacedDigit()
                }

                if tracker.granularity == .week {
                    UsageBarChart(
                        bars: detail.weekBars,
                        average: detail.averageBytes,
                        base: base,
                        highlightSelection: false,
                        onSelect: { tracker.selectDay(date: $0) }
                    )
                } else {
                    HourlyChart(hourly: detail.hourlyBars, base: base)
                }
            }

            Section {
                DirectionRows(bytesIn: detail.bytesIn, bytesOut: detail.bytesOut, base: base)
                LabeledContent("Average") {
                    Text(SpeedFormatter.formatData(bytes: detail.averageBytes, base: base))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(detail.displayName)
    }
}

// MARK: - Rows

private struct DirectionRows: View {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let base: UnitBase

    var body: some View {
        LabeledContent {
            Text(SpeedFormatter.formatData(bytes: bytesIn, base: base)).monospacedDigit()
        } label: {
            TintedLabel(title: "Download", systemImage: "circle.fill", tint: Semantic.download)
        }
        LabeledContent {
            Text(SpeedFormatter.formatData(bytes: bytesOut, base: base)).monospacedDigit()
        } label: {
            TintedLabel(title: "Upload", systemImage: "circle.fill", tint: Semantic.upload)
        }
    }
}

private struct AppUsageRow: View {
    let item: AppUsageDisplayItem
    let base: UnitBase

    var body: some View {
        let icon = AppInfoResolver.shared.icon(for: item.id, bundlePath: item.bundlePath, displayName: item.displayName)

        HStack {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Metrics.appIcon, height: Metrics.appIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(item.displayName).lineLimit(1)
                ProgressView(value: min(max(item.fractionOfMax, 0), 1))
            }

            Text(SpeedFormatter.formatData(bytes: item.totalBytes, base: base))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Charts (Swift Charts, macOS 13+)

private struct UsageBarChart: View {
    let bars: [WeekDayBarItem]
    let average: UInt64
    let base: UnitBase
    /// Day mode dims every day except the selected one; week mode shows all days equally.
    let highlightSelection: Bool
    let onSelect: (Date) -> Void

    var body: some View {
        let largest = bars.map(\.totalBytes).max() ?? 0
        let yMax = Double(max(largest, average, 1_048_576)) * 1.25

        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Day", bar.dateString),
                    y: .value("Bytes", bar.isFuture ? 0 : Double(bar.bytesIn))
                )
                .foregroundStyle(by: .value("Direction", "Download"))
                .opacity(dimmed(bar) ? 0.4 : 1)

                BarMark(
                    x: .value("Day", bar.dateString),
                    y: .value("Bytes", bar.isFuture ? 0 : Double(bar.bytesOut))
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
                .opacity(dimmed(bar) ? 0.4 : 1)
            }

            if average > 0 {
                RuleMark(y: .value("Average", Double(average)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(SpeedFormatter.formatData(bytes: average, base: base))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartForegroundStyleScale([
            "Download": Semantic.download,
            "Upload": Semantic.upload
        ])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yMax)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let bar = bars.first(where: { $0.dateString == id }) {
                        Text(bar.weekdayLetter)
                            .fontWeight(emphasized(bar) ? .bold : .regular)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(Double.self) {
                        Text(SpeedFormatter.formatData(bytes: UInt64(max(bytes, 0)), base: base))
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { event in
                            let x = event.location.x - geometry[proxy.plotAreaFrame].origin.x
                            if let id: String = proxy.value(atX: x),
                               let bar = bars.first(where: { $0.dateString == id }),
                               !bar.isFuture {
                                onSelect(bar.date)
                            }
                        }
                    )
            }
        }
        .frame(height: Metrics.chartHeight)
        .accessibilityLabel("Daily network usage. Select a day to see its hourly breakdown.")
    }

    private func dimmed(_ bar: WeekDayBarItem) -> Bool {
        highlightSelection && !bar.isSelected
    }

    private func emphasized(_ bar: WeekDayBarItem) -> Bool {
        highlightSelection ? bar.isSelected : bar.isToday
    }
}

private struct HourlyChart: View {
    let hourly: [HourlyUsageRecord]
    let base: UnitBase

    private func label(_ hour: Int) -> String { String(format: "%02d", hour) }

    var body: some View {
        let largest = hourly.map(\.totalBytes).max() ?? 0
        let yMax = Double(max(largest, 1_048_576)) * 1.25

        Chart {
            ForEach(hourly) { record in
                BarMark(
                    x: .value("Hour", label(record.hour)),
                    y: .value("Bytes", Double(record.bytesIn))
                )
                .foregroundStyle(by: .value("Direction", "Download"))

                BarMark(
                    x: .value("Hour", label(record.hour)),
                    y: .value("Bytes", Double(record.bytesOut))
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
            }
        }
        .chartForegroundStyleScale([
            "Download": Semantic.download,
            "Upload": Semantic.upload
        ])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yMax)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18].map(label)) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(Double.self) {
                        Text(SpeedFormatter.formatData(bytes: UInt64(max(bytes, 0)), base: base))
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: Metrics.chartHeight)
        .accessibilityLabel("Hourly network usage")
    }
}
