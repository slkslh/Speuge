import SwiftUI
import AppKit

public struct DataUsageView: View {
    @ObservedObject var tracker = DataUsageTracker.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var stats = NetworkStats.shared
    
    @State private var selectedAppId: String? = nil
    @State private var showingResetAlert: Bool = false
    @State private var isScrolled: Bool = false
    
    public var embeddedInMainApp: Bool
    
    public init(embeddedInMainApp: Bool = true) {
        self.embeddedInMainApp = embeddedInMainApp
    }
    
    public var body: some View {
        Group {
            if embeddedInMainApp {
                embeddedLayout
            } else {
                standaloneLayout
            }
        }
        .alert("Reset Data Usage?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Today", role: .destructive) {
                tracker.resetToday()
            }
            Button("Clear All History", role: .destructive) {
                tracker.resetAllHistory()
            }
        } message: {
            Text("Are you sure you want to reset recorded data usage statistics? This cannot be undone.")
        }
    }
    
    // MARK: - Embedded Layout (Matching Native macOS Settings Theme)
    
    private var embeddedLayout: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // Native Mac Header
                embeddedHeaderSection
                
                if let appId = selectedAppId {
                    // Individual App Detail View
                    appDetailView(appId: appId)
                } else {
                    // Main Screen Time View
                    mainScreenTimeView
                }
            }
            .padding(20)
        }
    }
    
    private var embeddedHeaderSection: some View {
        Group {
            if let appId = selectedAppId {
                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedAppId = nil
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .symbolRenderingMode(.hierarchical)
                            Text("Network Usage")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    if let app = tracker.screenTimeSummary.topApps.first(where: { $0.id == appId }) {
                        Text(app.displayName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Usage")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Bandwidth consumption per process, hardware adapter, and daily telemetry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
        }
    }
    
    // MARK: - Standalone Window Layout
    
    private var standaloneLayout: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ScrollDetector { scrollY in
                        let scrolled = scrollY > 2.0
                        if scrolled != isScrolled {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isScrolled = scrolled
                            }
                        }
                    }
                    .frame(width: 0, height: 0)
                    
                    VStack(spacing: 12) {
                        if let appId = selectedAppId {
                            appDetailView(appId: appId)
                        } else {
                            mainScreenTimeView
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 56)
                    .padding(.bottom, 20)
                }
            }
            
            appBarHeader
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Pinned App Bar (for Standalone Window)
    
    private var appBarHeader: some View {
        ZStack {
            if isScrolled {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Color(nsColor: .windowBackgroundColor).opacity(0.3)
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 0.5)
                }
                .transition(.opacity)
            }
            
            WindowDragBackground()
            
            HStack(spacing: 0) {
                if let _ = selectedAppId {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedAppId = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .symbolRenderingMode(.hierarchical)
                                .font(.caption.weight(.bold))
                            Text("Network Usage")
                                .font(.body)
                        }
                        .foregroundStyle(.blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 78)
                } else {
                    Spacer().frame(width: 78)
                }
                
                Spacer()
                
                Text(appBarTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Spacer().frame(width: selectedAppId != nil ? 180 : 78)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 52)
        .animation(.easeInOut(duration: 0.2), value: isScrolled)
    }
    
    private var appBarTitle: String {
        if let appId = selectedAppId,
           let app = tracker.screenTimeSummary.topApps.first(where: { $0.id == appId }) {
            return app.displayName
        }
        return "Network Usage"
    }
    
    // MARK: - MAIN SCREEN TIME VIEW (Image 1 & Image 3)
    
    private var mainScreenTimeView: some View {
        VStack(spacing: 12) {
            // Top Controls: Day/Week (wider) and Interface selection SIDE BY SIDE
            topControlsRow
            
            // Screen Time Card (Week mode or Day mode)
            if tracker.granularity == .week {
                weekMainCard // Image 3
            } else {
                dayMainCard // Image 1
            }
            
            // Footer: "Updated today at HH:mm"
            HStack {
                Text(tracker.screenTimeSummary.lastUpdatedString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, -4)
            
            // "Most Used" App Section
            mostUsedSection
        }
    }
    
    // MARK: - Top Controls Row (Day/Week and Interface side by side)
    
    private var topControlsRow: some View {
        HStack(spacing: 16) {
            // Interface Selector (on the left)
            HStack(spacing: 6) {
                Text("Interface:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $settings.selectedInterface) {
                    Text("All Interfaces").tag("all")
                    Text("Auto (Primary)").tag("auto")
                    Divider()
                    ForEach(stats.availableInterfaces) { intf in
                        Text(intf.displayName).tag(intf.bsdName)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: 155)
                .onChange(of: settings.selectedInterface) { _ in
                    NetworkMonitor.shared.updateInterval()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            
            Spacer()
            
            // [ Day | Week ] Apple Built-in Segmented Control matching OS version
            Picker("", selection: $tracker.granularity) {
                ForEach([UsageGranularity.day, UsageGranularity.week]) { gran in
                    Text(gran.rawValue).tag(gran)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 170)
        }
    }
    
    // MARK: - Navigation Header (Title / Back Button)
    
    private func headerNavigationRow(title: String, showBack: Bool, onBack: (() -> Void)? = nil) -> some View {
        HStack(alignment: .center) {
            if showBack {
                Button(action: { onBack?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .symbolRenderingMode(.hierarchical)
                            .font(.caption.weight(.bold))
                        Text(title)
                            .font(.body)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Date Stepper Navigation Pill (Fixed Size: < | Label | >)
    
    private var dateStepperNavigationPill: some View {
        HStack(spacing: 0) {
            // Back (<)
            Button(action: { tracker.goToPrevious() }) {
                Image(systemName: "chevron.left")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tracker.canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!tracker.canGoBack)
            
            Divider()
                .frame(height: 12)
                .opacity(0.3)
            
            // Label (jump to current) - Fixed Width so pill never resizes or jumps
            Button(action: { tracker.goToCurrent() }) {
                Text(tracker.screenTimeSummary.headerNavTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 92, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 12)
                .opacity(0.3)
            
            // Forward (>)
            Button(action: { tracker.goToNext() }) {
                Image(systemName: "chevron.right")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tracker.canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!tracker.canGoForward)
        }
        .frame(width: 142, height: 24)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
    
    // MARK: - WEEK MAIN CARD (Exact Image 3 Match)
    
    private var weekMainCard: some View {
        let summary = tracker.screenTimeSummary
        let downStr = SpeedFormatter.formatData(bytes: summary.totalBytesIn, base: settings.unitBase)
        let upStr = SpeedFormatter.formatData(bytes: summary.totalBytesOut, base: settings.unitBase)
        let totalStr = SpeedFormatter.formatData(bytes: summary.totalBytes, base: settings.unitBase)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: Subtitle (left) + Date Selector (right, fixed size)
            HStack(alignment: .center) {
                Text(summary.cardSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                dateStepperNavigationPill
            }
            
            // Value & Trend Row
            HStack(alignment: .firstTextBaseline) {
                Text(summary.mainValueFormatted)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let trend = summary.trendText {
                    HStack(spacing: 4) {
                        Image(systemName: summary.trendIsUp == true ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.caption)
                        Text(trend)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            // 7-Day Chart (M T W T F S S with stacked download/upload and avg line)
            weekBarsChart(
                bars: summary.weekDays,
                dailyAvg: summary.dailyAverageBytes,
                maxDay: summary.maxDayBytes
            )
            .padding(.top, 4)
            .padding(.bottom, 6)
            
            // Legend Categories
            categoriesLegend(downStr: downStr, upStr: upStr)
            
            Divider()
            
            // Total Row
            HStack {
                Text("Total Network Usage")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(totalStr)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
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
    
    // MARK: - DAY MAIN CARD (Exact Image 1 Match)
    
    private var dayMainCard: some View {
        let summary = tracker.screenTimeSummary
        let downStr = SpeedFormatter.formatData(bytes: summary.totalBytesIn, base: settings.unitBase)
        let upStr = SpeedFormatter.formatData(bytes: summary.totalBytesOut, base: settings.unitBase)
        let totalStr = SpeedFormatter.formatData(bytes: summary.totalBytes, base: settings.unitBase)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: Subtitle (left) + Date Selector (right, fixed size)
            HStack(alignment: .center) {
                Text(summary.cardSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                dateStepperNavigationPill
            }
            
            // Large Value Row
            HStack(alignment: .firstTextBaseline) {
                Text(summary.mainValueFormatted)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let trend = summary.trendText {
                    HStack(spacing: 4) {
                        Image(systemName: summary.trendIsUp == true ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.caption)
                        Text(trend)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            // 1. Upper Chart: 7 Days Context
            upperWeekContextChart(
                bars: summary.weekDays,
                maxDay: summary.maxDayBytes,
                dailyAvg: summary.dailyAverageBytes
            )
            .padding(.top, 2)
            
            // 2. Lower Chart: 24-Hour Breakdown
            hourlyChart(hourly: summary.hourlyUsage, maxHour: summary.maxHourBytes)
                .padding(.vertical, 4)
            
            // Legend Categories
            categoriesLegend(downStr: downStr, upStr: upStr)
            
            Divider()
            
            // Total Row
            HStack {
                Text("Total Network Usage")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(totalStr)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
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
    
    // MARK: - Upper Week Context Chart (for Day Mode - Image 1)
    
    private func upperWeekContextChart(bars: [WeekDayBarItem], maxDay: UInt64, dailyAvg: UInt64) -> some View {
        let chartHeight: CGFloat = 88
        let barWidth: CGFloat = 36
        let rightLabelWidth: CGFloat = 66
        let effectiveMax = Double(max(maxDay, dailyAvg, 1_048_576)) * 1.25
        let avgRatio = CGFloat(min(max(Double(dailyAvg) / effectiveMax, 0.05), 0.95))
        let avgY = chartHeight * (1.0 - avgRatio)
        
        return ZStack(alignment: .topLeading) {
            // Reference Lines & Right Labels
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                    Text(SpeedFormatter.formatData(bytes: UInt64(effectiveMax), base: settings.unitBase))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: rightLabelWidth, alignment: .trailing)
                }
                Spacer()
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5)
                    if dailyAvg == 0 || avgRatio >= 0.20 {
                        Text("0 B")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: rightLabelWidth, alignment: .trailing)
                    } else {
                        Color.clear.frame(width: rightLabelWidth, height: 1)
                    }
                }
            }
            .frame(height: chartHeight)
            
            // Average Line with "avg" Label
            if dailyAvg > 0 {
                HStack(spacing: 0) {
                    Line()
                        .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(height: 1)
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("avg")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(SpeedFormatter.formatData(bytes: dailyAvg, base: settings.unitBase))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: rightLabelWidth, alignment: .trailing)
                }
                .frame(height: 18)
                .offset(y: avgY - 9)
            }
            
            // 7 Columns
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(bars) { bar in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tracker.selectDay(date: bar.date)
                        }
                    }) {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                // Background track
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.primary.opacity(bar.isSelected ? 0.08 : 0.03))
                                    .frame(width: barWidth, height: chartHeight)
                                
                                if !bar.isFuture && bar.totalBytes > 0 {
                                    let totalH = max(CGFloat(Double(bar.totalBytes) / effectiveMax) * chartHeight, 4)
                                    
                                    if bar.isSelected {
                                        // Selected day: 2 vibrant colors (Blue Download + Orange Upload)
                                        let inRatio = CGFloat(Double(bar.bytesIn) / Double(bar.totalBytes))
                                        let inH = totalH * inRatio
                                        let outH = totalH - inH
                                        
                                        VStack(spacing: 0) {
                                            if outH > 0 {
                                                Rectangle().fill(Color.orange).frame(height: outH)
                                            }
                                            if inH > 0 {
                                                Rectangle().fill(Color.blue).frame(height: inH)
                                            }
                                        }
                                        .frame(width: barWidth, height: totalH)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    } else {
                                        // Non-selected days: Dim Gray (Exact Image 1 Match!)
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(Color.primary.opacity(0.22))
                                            .frame(width: barWidth, height: totalH)
                                    }
                                }
                            }
                            
                            // Day letter M, T, W, T, F, S, S
                            Text(bar.weekdayLetter)
                                .font(.caption.weight(bar.isSelected ? .bold : .medium))
                                .foregroundStyle(bar.isSelected ? Color.blue : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(bar.isFuture)
                    .help("\(bar.fullDayName): ↓ \(SpeedFormatter.formatData(bytes: bar.bytesIn)) • ↑ \(SpeedFormatter.formatData(bytes: bar.bytesOut)) — Click to view day")
                }
                
                Spacer().frame(width: rightLabelWidth)
            }
            .frame(height: chartHeight + 20)
        }
    }
    
    // MARK: - 24-Hour Lower Chart (for Day Mode - Image 1 & Image 2)
    
    private func hourlyChart(hourly: [HourlyUsageRecord], maxHour: UInt64) -> some View {
        let chartHeight: CGFloat = 78
        let barWidth: CGFloat = 12
        let rightLabelWidth: CGFloat = 66
        let effectiveMax = Double(max(maxHour, 1_048_576)) * 1.25
        
        return ZStack(alignment: .topLeading) {
            // Guidelines & Right Labels (Max, Mid, 0 B)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
                    Text(SpeedFormatter.formatData(bytes: UInt64(effectiveMax), base: settings.unitBase))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: rightLabelWidth, alignment: .trailing)
                }
                Spacer()
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 0.5)
                    Text(SpeedFormatter.formatData(bytes: UInt64(effectiveMax / 2), base: settings.unitBase))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: rightLabelWidth, alignment: .trailing)
                }
                Spacer()
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
                    Text("0 B")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: rightLabelWidth, alignment: .trailing)
                }
            }
            .frame(height: chartHeight)
            
            // 24 Hour Bars (00 through 23)
            VStack(spacing: 5) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(hourly) { h in
                        ZStack(alignment: .bottom) {
                            // Faint slot
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                                .frame(width: barWidth, height: chartHeight)
                            
                            if h.totalBytes > 0 {
                                let totalH = max(CGFloat(Double(h.totalBytes) / effectiveMax) * chartHeight, 3)
                                let inRatio = CGFloat(Double(h.bytesIn) / Double(h.totalBytes))
                                let inH = totalH * inRatio
                                let outH = totalH - inH
                                
                                // 2 Colors: Download Blue + Upload Orange
                                VStack(spacing: 0) {
                                    if outH > 0 {
                                        Rectangle().fill(Color.orange).frame(height: outH)
                                    }
                                    if inH > 0 {
                                        Rectangle().fill(Color.blue).frame(height: inH)
                                    }
                                }
                                .frame(width: barWidth, height: totalH)
                                .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .help("Hour \(String(format: "%02d:00", h.hour)): ↓ \(SpeedFormatter.formatData(bytes: h.bytesIn)) • ↑ \(SpeedFormatter.formatData(bytes: h.bytesOut))")
                    }
                    
                    Spacer().frame(width: rightLabelWidth)
                }
                .frame(height: chartHeight)
                
                // Hour Markers (00, 06, 12, 18) perfectly aligned to hours 0, 6, 12, 18
                HStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hr in
                        Group {
                            if hr == 0 {
                                Text("00").font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                            } else if hr == 6 {
                                Text("06").font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                            } else if hr == 12 {
                                Text("12").font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                            } else if hr == 18 {
                                Text("18").font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Spacer().frame(width: rightLabelWidth)
                }
            }
        }
    }
    
    // MARK: - Week 7-Day Chart Helper
    
    private func weekBarsChart(bars: [WeekDayBarItem], dailyAvg: UInt64, maxDay: UInt64, onSelectDay: ((Date) -> Void)? = nil) -> some View {
        let chartHeight: CGFloat = 122
        let barWidth: CGFloat = 36
        let rightLabelWidth: CGFloat = 66
        let effectiveMax = Double(max(maxDay, dailyAvg, 1_048_576)) * 1.25
        let avgRatio = CGFloat(min(max(Double(dailyAvg) / effectiveMax, 0.05), 0.95))
        let avgY = chartHeight * (1.0 - avgRatio)
        
        return ZStack(alignment: .topLeading) {
            // Horizontal Gridlines
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                    Text(SpeedFormatter.formatData(bytes: UInt64(effectiveMax), base: settings.unitBase))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: rightLabelWidth, alignment: .trailing)
                }
                Spacer()
                HStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5)
                    if dailyAvg == 0 || avgRatio >= 0.20 {
                        Text("0 B")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: rightLabelWidth, alignment: .trailing)
                    } else {
                        Color.clear.frame(width: rightLabelWidth, height: 1)
                    }
                }
            }
            .frame(height: chartHeight)
            
            // Average Line with "avg" Label
            if dailyAvg > 0 {
                HStack(spacing: 0) {
                    Line()
                        .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(height: 1)
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("avg")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(SpeedFormatter.formatData(bytes: dailyAvg, base: settings.unitBase))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: rightLabelWidth, alignment: .trailing)
                }
                .frame(height: 20)
                .offset(y: avgY - 10)
            }
            
            // 7 Bars
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(bars) { bar in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if let onSelect = onSelectDay {
                                onSelect(bar.date)
                            } else {
                                tracker.selectDay(date: bar.date)
                            }
                        }
                    }) {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.primary.opacity(bar.isToday ? 0.08 : 0.03))
                                    .frame(width: barWidth, height: chartHeight)
                                
                                if !bar.isFuture && bar.totalBytes > 0 {
                                    let totalH = max(CGFloat(Double(bar.totalBytes) / effectiveMax) * chartHeight, 4)
                                    let inRatio = CGFloat(Double(bar.bytesIn) / Double(bar.totalBytes))
                                    let inH = totalH * inRatio
                                    let outH = totalH - inH
                                    
                                    VStack(spacing: 0) {
                                        if outH > 0 {
                                            Rectangle().fill(Color.orange).frame(height: outH)
                                        }
                                        if inH > 0 {
                                            Rectangle().fill(Color.blue).frame(height: inH)
                                        }
                                    }
                                    .frame(width: barWidth, height: totalH)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                            }
                            
                            Text(bar.weekdayLetter)
                                .font(.caption.weight(bar.isToday ? .bold : .medium))
                                .foregroundStyle(bar.isToday ? Color.blue : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(bar.isFuture)
                    .help("\(bar.fullDayName): ↓ \(SpeedFormatter.formatData(bytes: bar.bytesIn)) • ↑ \(SpeedFormatter.formatData(bytes: bar.bytesOut)) — Click to view day")
                }
                
                Spacer().frame(width: rightLabelWidth)
            }
            .frame(height: chartHeight + 22)
        }
    }
    
    // MARK: - Legend Component
    
    private func categoriesLegend(downStr: String, upStr: String) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Download")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.blue)
                Text(downStr)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Upload")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                Text(upStr)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Button(action: { showingResetAlert = true }) {
                Image(systemName: "arrow.counterclockwise")
                    .symbolRenderingMode(.hierarchical)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reset Usage Statistics")
        }
    }
    
    // MARK: - Most Used Section (Apps List)
    
    private var mostUsedSection: some View {
        let summary = tracker.screenTimeSummary
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Most Used")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Apple-style Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .symbolRenderingMode(.hierarchical)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Search Apps", text: $tracker.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .frame(width: 165)
                    
                    if !tracker.searchQuery.isEmpty {
                        Button(action: { tracker.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 2)
            
            if summary.topApps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "app.badge.checkmark")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.top, 16)
                    Text("No App Activity Logged")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Network usage from applications will automatically be tracked here.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.topApps.prefix(30).enumerated()), id: \.element.id) { index, app in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedAppId = app.id
                            }
                        }) {
                            screenTimeAppRow(item: app)
                        }
                        .buttonStyle(PlainHoverButtonStyle())
                        
                        if index < min(summary.topApps.count, 30) - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
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
    }
    
    private func screenTimeAppRow(item: AppUsageDisplayItem) -> some View {
        let icon = AppInfoResolver.shared.icon(
            for: item.id,
            bundlePath: item.bundlePath,
            displayName: item.displayName
        )
        let totalStr = SpeedFormatter.formatData(bytes: item.totalBytes, base: settings.unitBase)
        
        return HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.primary.opacity(0.12))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.primary.opacity(0.38))
                                .frame(width: max(geo.size.width * CGFloat(item.fractionOfMax), 4), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text(totalStr)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .symbolRenderingMode(.hierarchical)
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - INDIVIDUAL APP DETAIL VIEW (Exact Match to Image 2 & Image 4)
    
    private func appDetailView(appId: String) -> some View {
        let appDetail = tracker.getAppDetail(appId: appId)
        let icon = AppInfoResolver.shared.icon(
            for: appId,
            bundlePath: appDetail.bundlePath,
            displayName: appDetail.displayName
        )
        let totalStr = SpeedFormatter.formatData(bytes: appDetail.totalBytes, base: settings.unitBase)
        let avgStr = SpeedFormatter.formatData(bytes: appDetail.averageBytes, base: settings.unitBase)
        let downStr = SpeedFormatter.formatData(bytes: appDetail.bytesIn, base: settings.unitBase)
        let upStr = SpeedFormatter.formatData(bytes: appDetail.bytesOut, base: settings.unitBase)
        
        return VStack(spacing: 12) {
            // Top Controls: Day/Week and Interface selection SIDE BY SIDE
            topControlsRow
            
            // Header Navigation: Back Button + Stepper Navigation
            headerNavigationRow(title: "Network Usage", showBack: true) {
                selectedAppId = nil
            }
            
            // App Header Card
            HStack(spacing: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .cornerRadius(7)
                
                Text(appDetail.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            
            // App Usage Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(tracker.granularity == .day ? tracker.screenTimeSummary.cardSubtitle : "Total Usage")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    dateStepperNavigationPill
                }
                
                Text(totalStr)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                // Chart (Week or Day)
                if tracker.granularity == .week {
                    let maxVal = appDetail.weekBars.map { $0.totalBytes }.max() ?? 0
                    weekBarsChart(
                        bars: appDetail.weekBars,
                        dailyAvg: appDetail.averageBytes,
                        maxDay: maxVal,
                        onSelectDay: { date in
                            tracker.selectDay(date: date)
                        }
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                } else {
                    let maxH = appDetail.hourlyBars.map { $0.totalBytes }.max() ?? 0
                    hourlyChart(hourly: appDetail.hourlyBars, maxHour: maxH)
                        .padding(.vertical, 4)
                }
                
                // Legend
                categoriesLegend(downStr: downStr, upStr: upStr)
                
                Divider()
                
                // Average Row
                HStack {
                    Text("Average")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(avgStr)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
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
            
            Spacer()
        }
    }
}

// MARK: - Plain Hover Button Style

private struct PlainHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}

// MARK: - Dashed Line Shape

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - App Bar Window Dragging & Scroll Tracking

final class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct WindowDragBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView {
        WindowDragView()
    }
    func updateNSView(_ nsView: WindowDragView, context: Context) {}
}

struct ScrollDetector: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.setup(for: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }
    
    class Coordinator: NSObject {
        var onScroll: (CGFloat) -> Void
        private var isObserving = false
        private weak var observedClipView: NSClipView?
        
        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }
        
        func setup(for view: NSView) {
            guard !isObserving, let scrollView = view.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView
            isObserving = true
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
            onScroll(clipView.bounds.origin.y)
        }
        
        @objc private func boundsDidChange(_ notification: Notification) {
            guard let clipView = observedClipView else { return }
            onScroll(clipView.bounds.origin.y)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

