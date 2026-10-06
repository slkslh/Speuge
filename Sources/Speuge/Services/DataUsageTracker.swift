import Foundation
import SwiftUI
import AppKit

@MainActor
public final class DataUsageTracker: ObservableObject {
    public static let shared = DataUsageTracker()
    
    // Screen Time Style State
    @Published public var granularity: UsageGranularity = .day {
        didSet { recalculateSummary() }
    }
    
    @Published public var weekOffset: Int = 0 { // 0 = this week, -1 = last week, down to -4 (~30 days)
        didSet { recalculateSummary() }
    }
    
    @Published public var dayOffset: Int = 0 {  // 0 = today, -1 = yesterday, down to -30
        didSet { recalculateSummary() }
    }
    
    @Published public var screenTimeSummary: ScreenTimeUsageSummary = ScreenTimeUsageSummary()
    
    // Legacy / Overview State
    @Published public var selectedFilter: UsageTimeFilter = .week {
        didSet { recalculateSummary() }
    }
    
    @Published public var searchQuery: String = "" {
        didSet { recalculateSummary() }
    }
    
    @Published public var summary: DataUsageSummary = DataUsageSummary()
    @Published public var todayTotalBytes: UInt64 = 0
    @Published public var todayTotalFormatted: String = "0 B"
    @Published public var todayAppCount: Int = 0
    
    // Internal State
    private var storeData: UsageHistoryStoreData = UsageHistoryStoreData()
    private var previousCounters: [String: (UInt64, UInt64)] = [:]
    private var isFirstCycle: Bool = true
    private var isDirty: Bool = false
    
    private let sampleQueue = DispatchQueue(label: "com.networkspeed.datausage", qos: .utility)
    private var sampleTimer: DispatchSourceTimer?
    private var saveTimer: DispatchSourceTimer?
    
    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Speuge", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("data_usage.json")
    }()
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()
    
    private init() {
        loadFromDisk()
        recalculateSummary()
    }
    
    // MARK: - Lifecycle
    
    public func start() {
        stop()
        startSamplingTimer()
        startAutosaveTimer()
    }
    
    public func stop() {
        sampleTimer?.cancel()
        sampleTimer = nil
        saveTimer?.cancel()
        saveTimer = nil
        saveToDisk()
    }
    
    // MARK: - Navigation Actions (Screen Time Style)
    
    public var canGoBack: Bool {
        if granularity == .week {
            return weekOffset > -4 // Up to 5 weeks (~35 days)
        } else {
            return dayOffset > -30 // Up to 30 days
        }
    }
    
    public var canGoForward: Bool {
        if granularity == .week {
            return weekOffset < 0
        } else {
            return dayOffset < 0
        }
    }
    
    public func goToPrevious() {
        if granularity == .week {
            if canGoBack { weekOffset -= 1 }
        } else {
            if canGoBack { dayOffset -= 1 }
        }
    }
    
    public func goToNext() {
        if granularity == .week {
            if canGoForward { weekOffset += 1 }
        } else {
            if canGoForward { dayOffset += 1 }
        }
    }
    
    public func goToCurrent() {
        weekOffset = 0
        dayOffset = 0
    }
    
    public func selectDay(date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        if let diff = calendar.dateComponents([.day], from: today, to: target).day {
            self.dayOffset = diff
            self.granularity = .day
            recalculateSummary()
        }
    }
    
    // MARK: - Background Sampling
    
    private func startSamplingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        timer.schedule(deadline: .now() + 1.0, repeating: 2.5)
        timer.setEventHandler { [weak self] in
            self?.performSample()
        }
        timer.resume()
        self.sampleTimer = timer
    }
    
    private func startAutosaveTimer() {
        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        timer.schedule(deadline: .now() + 30.0, repeating: 30.0)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.saveToDisk()
            }
        }
        timer.resume()
        self.saveTimer = timer
    }
    
    private func performSample() {
        let samples = runNettop()
        guard !samples.isEmpty else { return }
        
        var deltas: [(procKey: String, inDelta: UInt64, outDelta: UInt64)] = []
        
        if isFirstCycle {
            for (procKey, inBytes, outBytes) in samples {
                previousCounters[procKey] = (inBytes, outBytes)
            }
            isFirstCycle = false
            return
        }
        
        var currentKeys = Set<String>()
        for (procKey, inBytes, outBytes) in samples {
            currentKeys.insert(procKey)
            
            if let prev = previousCounters[procKey] {
                let deltaIn = inBytes >= prev.0 ? (inBytes - prev.0) : 0
                let deltaOut = outBytes >= prev.1 ? (outBytes - prev.1) : 0
                
                if deltaIn > 0 || deltaOut > 0 {
                    deltas.append((procKey, deltaIn, deltaOut))
                }
            } else {
                let deltaIn = inBytes < 50_000_000 ? inBytes : 0
                let deltaOut = outBytes < 50_000_000 ? outBytes : 0
                if deltaIn > 0 || deltaOut > 0 {
                    deltas.append((procKey, deltaIn, deltaOut))
                }
            }
            
            previousCounters[procKey] = (inBytes, outBytes)
        }
        
        if previousCounters.count > 300 {
            previousCounters = previousCounters.filter { currentKeys.contains($0.key) }
        }
        
        guard !deltas.isEmpty else { return }
        
        Task { @MainActor [weak self] in
            self?.applyDeltas(deltas)
        }
    }
    
    private func runNettop() -> [(String, UInt64, UInt64)] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        proc.arguments = ["-P", "-L", "1", "-x", "-t", "external", "-J", "bytes_in,bytes_out"]
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            var results: [(String, UInt64, UInt64)] = []
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.contains("bytes_in") { continue }
                let parts = trimmed.split(separator: ",")
                if parts.count >= 3 {
                    let key = String(parts[0])
                    let bIn = UInt64(parts[1]) ?? 0
                    let bOut = UInt64(parts[2]) ?? 0
                    results.append((key, bIn, bOut))
                }
            }
            return results
        } catch {
            return []
        }
    }
    
    // MARK: - State Mutation
    
    private func applyDeltas(_ deltas: [(procKey: String, inDelta: UInt64, outDelta: UInt64)]) {
        let now = Date()
        let todayKey = dateFormatter.string(from: now)
        let hour = Calendar.current.component(.hour, from: now)
        
        var snapshot = storeData.dailyRecords[todayKey] ?? DailyUsageSnapshot(dateString: todayKey)
        if snapshot.hourlyUsage.count < 24 {
            snapshot.hourlyUsage = (0..<24).map { HourlyUsageRecord(hour: $0) }
        }
        
        for delta in deltas {
            snapshot.totalBytesIn += delta.inDelta
            snapshot.totalBytesOut += delta.outDelta
            
            if hour >= 0 && hour < 24 {
                snapshot.hourlyUsage[hour].bytesIn += delta.inDelta
                snapshot.hourlyUsage[hour].bytesOut += delta.outDelta
            }
            
            let appMeta = AppInfoResolver.shared.resolve(procKey: delta.procKey, pid: nil)
            var appRecord = snapshot.apps[appMeta.id] ?? ProcessUsageRecord(
                id: appMeta.id,
                displayName: appMeta.displayName,
                bundlePath: appMeta.bundlePath
            )
            
            if appRecord.hourlyUsage.count < 24 {
                appRecord.hourlyUsage = (0..<24).map { HourlyUsageRecord(hour: $0) }
            }
            
            appRecord.bytesIn += delta.inDelta
            appRecord.bytesOut += delta.outDelta
            if hour >= 0 && hour < 24 {
                appRecord.hourlyUsage[hour].bytesIn += delta.inDelta
                appRecord.hourlyUsage[hour].bytesOut += delta.outDelta
            }
            
            appRecord.displayName = appMeta.displayName
            if appRecord.bundlePath == nil {
                appRecord.bundlePath = appMeta.bundlePath
            }
            appRecord.lastSeen = now
            snapshot.apps[appMeta.id] = appRecord
        }
        
        storeData.dailyRecords[todayKey] = snapshot
        isDirty = true
        
        recalculateSummary()
    }
    
    // MARK: - Summary Calculation (Screen Time + Legacy)
    
    public func recalculateSummary() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday start
        let now = Date()
        let todayKey = dateFormatter.string(from: now)
        
        // Today quick stats
        if let todaySnap = storeData.dailyRecords[todayKey] {
            todayTotalBytes = todaySnap.totalBytes
            todayTotalFormatted = SpeedFormatter.formatData(bytes: todayTotalBytes, base: AppSettings.shared.unitBase)
            todayAppCount = todaySnap.apps.count
        } else {
            todayTotalBytes = 0
            todayTotalFormatted = "0 B"
            todayAppCount = 0
        }
        
        // --- SCREEN TIME STYLE CALCULATION ---
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let updatedStr = "Updated today at \(timeFormatter.string(from: now))"
        
        if granularity == .week {
            computeWeekSummary(calendar: calendar, now: now, updatedStr: updatedStr)
        } else {
            computeDaySummary(calendar: calendar, now: now, updatedStr: updatedStr)
        }
    }
    
    private func computeWeekSummary(calendar: Calendar, now: Date, updatedStr: String) {
        guard let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now),
              let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetWeekDate)) else {
            return
        }
        
        let letterFormatter = DateFormatter()
        letterFormatter.dateFormat = "EEEEE" // M, T, W, T, F, S, S
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        
        var weekBars: [WeekDayBarItem] = []
        var weekIn: UInt64 = 0
        var weekOut: UInt64 = 0
        var maxDay: UInt64 = 0
        var aggregatedApps: [String: ProcessUsageRecord] = [:]
        
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dateStr = dateFormatter.string(from: dayDate)
            let isToday = calendar.isDateInToday(dayDate)
            let isFuture = dayDate > now && !isToday
            
            let snap = storeData.dailyRecords[dateStr]
            let dIn = isFuture ? 0 : (snap?.totalBytesIn ?? 0)
            let dOut = isFuture ? 0 : (snap?.totalBytesOut ?? 0)
            let dTotal = dIn + dOut
            
            weekIn += dIn
            weekOut += dOut
            if dTotal > maxDay {
                maxDay = dTotal
            }
            
            if let apps = snap?.apps, !isFuture {
                for (id, app) in apps {
                    if var existing = aggregatedApps[id] {
                        existing.bytesIn += app.bytesIn
                        existing.bytesOut += app.bytesOut
                        aggregatedApps[id] = existing
                    } else {
                        aggregatedApps[id] = app
                    }
                }
            }
            
            weekBars.append(WeekDayBarItem(
                date: dayDate,
                dateString: dateStr,
                weekdayLetter: letterFormatter.string(from: dayDate),
                fullDayName: dayNameFormatter.string(from: dayDate),
                bytesIn: dIn,
                bytesOut: dOut,
                totalBytes: dTotal,
                isToday: isToday,
                isFuture: isFuture,
                isSelected: false
            ))
        }
        
        let weekTotal = weekIn + weekOut
        
        // Count active days with recorded data (non-future days with usage)
        let daysWithData = weekBars.filter { !$0.isFuture && $0.totalBytes > 0 }.count
        let divisor: Int
        if weekOffset < 0 {
            // Completed past week:
            // If full week of data (>= 5 active days recorded), standard 7-day week divisor is 7.
            // If only a few days recorded (e.g. app installed mid-week), divide by active recorded days.
            divisor = daysWithData >= 5 ? 7 : max(1, daysWithData)
        } else {
            // Current week in progress (or future):
            // Divides by active days recorded so far (e.g. 1 on Monday, 2 on Tuesday, etc.)
            divisor = max(1, daysWithData)
        }
        let dailyAvg = weekTotal > 0 ? (weekTotal / UInt64(divisor)) : 0
        
        // Previous week calculation for trend
        var prevWeekTotal: UInt64 = 0
        var prevDaysWithData = 0
        if let prevWeekTarget = calendar.date(byAdding: .weekOfYear, value: weekOffset - 1, to: now),
           let prevWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: prevWeekTarget)) {
            for i in 0..<7 {
                if let prevDate = calendar.date(byAdding: .day, value: i, to: prevWeekStart) {
                    let prevStr = dateFormatter.string(from: prevDate)
                    if let snap = storeData.dailyRecords[prevStr] {
                        prevWeekTotal += snap.totalBytes
                        if snap.totalBytes > 0 {
                            prevDaysWithData += 1
                        }
                    }
                }
            }
        }
        let prevDivisor = prevDaysWithData >= 5 ? 7 : max(1, prevDaysWithData)
        let prevDailyAvg = prevWeekTotal > 0 ? (prevWeekTotal / UInt64(prevDivisor)) : 0
        
        // Show trend badge only when comparing completed past weeks (weekOffset < 0)
        // or current week once enough days have elapsed (daysWithData >= 3), matching Apple Screen Time.
        let showTrend = (weekOffset < 0) || (daysWithData >= 3)
        let trendText: String?
        let trendIsUp: Bool?
        if showTrend && prevDailyAvg > 0 && dailyAvg > 0 {
            let diff = Int(round(Double(Int64(dailyAvg) - Int64(prevDailyAvg)) / Double(prevDailyAvg) * 100))
            if diff >= 0 {
                trendText = "↑ \(diff)% from last week"
                trendIsUp = true
            } else {
                trendText = "↓ \(abs(diff))% from last week"
                trendIsUp = false
            }
        } else {
            trendText = nil
            trendIsUp = nil
        }
        
        // Format week range label
        let rangeDf = DateFormatter()
        rangeDf.dateFormat = "MMM d"
        let startLabel = rangeDf.string(from: weekBars.first?.date ?? now)
        let endLabel = rangeDf.string(from: weekBars.last?.date ?? now)
        let rangeText = "\(startLabel)–\(endLabel)"
        
        let navTitle = (weekOffset == 0) ? "Today" : rangeText
        let cardSub = (weekOffset == 0) ? "Daily Average" : (weekOffset == -1 ? "Last Week’s Average" : "\(rangeText) Average")
        let mainVal = SpeedFormatter.formatData(bytes: dailyAvg, base: AppSettings.shared.unitBase)
        
        let displayItems = formatAppsList(aggregatedApps: aggregatedApps, grandTotal: weekTotal)
        
        self.screenTimeSummary = ScreenTimeUsageSummary(
            granularity: .week,
            weekOffset: weekOffset,
            dayOffset: dayOffset,
            headerNavTitle: navTitle,
            cardSubtitle: cardSub,
            mainValueFormatted: mainVal,
            trendText: trendText,
            trendIsUp: trendIsUp,
            weekDays: weekBars,
            hourlyUsage: [],
            maxDayBytes: maxDay,
            maxHourBytes: 0,
            dailyAverageBytes: dailyAvg,
            totalBytesIn: weekIn,
            totalBytesOut: weekOut,
            totalBytes: weekTotal,
            appCount: displayItems.count,
            topApps: displayItems,
            lastUpdatedString: updatedStr,
            canGoBack: canGoBack,
            canGoForward: canGoForward
        )
        
        self.summary = DataUsageSummary(
            filter: .week,
            totalBytesIn: weekIn,
            totalBytesOut: weekOut,
            totalBytes: weekTotal,
            appCount: displayItems.count,
            topApps: displayItems,
            dailyBars: []
        )
    }
    
    private func computeDaySummary(calendar: Calendar, now: Date, updatedStr: String) {
        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return }
        let dateStr = dateFormatter.string(from: targetDate)
        let isToday = calendar.isDateInToday(targetDate)
        
        let snap = storeData.dailyRecords[dateStr]
        let dayIn = snap?.totalBytesIn ?? 0
        let dayOut = snap?.totalBytesOut ?? 0
        let dayTotal = dayIn + dayOut
        
        // Exact Screen Time day subtitle format: "Sunday, 27 September"
        let fullDayFormatter = DateFormatter()
        fullDayFormatter.dateFormat = "EEEE, d MMMM"
        let cardSub = fullDayFormatter.string(from: targetDate)
        
        let navTitle: String
        if isToday {
            navTitle = "Today"
        } else if calendar.isDateInYesterday(targetDate) {
            navTitle = "Yesterday"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            navTitle = df.string(from: targetDate)
        }
        
        // Day mode does not display a trend comparison badge (matches Apple Screen Time in Image 3 & Image 4)
        let trendText: String? = nil
        let trendIsUp: Bool? = nil
        
        // 7-day upper context chart for Day mode (Image 1)
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        let weekStart = weekCalendar.date(from: weekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)) ?? targetDate
        
        let letterFormatter = DateFormatter()
        letterFormatter.dateFormat = "EEEEE"
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        
        var weekBars: [WeekDayBarItem] = []
        var maxDay: UInt64 = dayTotal
        var weekTotalForAvg: UInt64 = 0
        var weekDaysCount: Int = 0
        
        for i in 0..<7 {
            guard let dDate = weekCalendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dStr = dateFormatter.string(from: dDate)
            let isCurrentSelected = calendar.isDate(dDate, inSameDayAs: targetDate)
            let isActuallyToday = calendar.isDateInToday(dDate)
            let isFuture = dDate > now && !isActuallyToday
            
            let dSnap = storeData.dailyRecords[dStr]
            let dIn = isFuture ? 0 : (dSnap?.totalBytesIn ?? 0)
            let dOut = isFuture ? 0 : (dSnap?.totalBytesOut ?? 0)
            let dTot = dIn + dOut
            if dTot > maxDay { maxDay = dTot }
            
            if !isFuture {
                weekTotalForAvg += dTot
                weekDaysCount += 1
            }
            
            weekBars.append(WeekDayBarItem(
                date: dDate,
                dateString: dStr,
                weekdayLetter: letterFormatter.string(from: dDate),
                fullDayName: dayNameFormatter.string(from: dDate),
                bytesIn: dIn,
                bytesOut: dOut,
                totalBytes: dTot,
                isToday: isActuallyToday,
                isFuture: isFuture,
                isSelected: isCurrentSelected
            ))
        }
        
        // Daily average of the 7-day context week:
        // Dynamically adapts based on whether full week is recorded vs a few days (Image 1/4 vs Image 2/3)
        let daysWithData = weekBars.filter { !$0.isFuture && $0.totalBytes > 0 }.count
        let isPastWeek = (weekBars.last?.date ?? targetDate) < calendar.startOfDay(for: now)
        let divisor: Int
        if isPastWeek {
            divisor = daysWithData >= 5 ? 7 : max(1, daysWithData)
        } else {
            divisor = max(1, daysWithData)
        }
        let weekDailyAvg = weekTotalForAvg > 0 ? (weekTotalForAvg / UInt64(divisor)) : 0
        
        // 24-hour lower chart
        let hourly = snap?.hourlyUsage ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
        let maxHour = hourly.map { $0.totalBytes }.max() ?? 0
        
        let mainVal = SpeedFormatter.formatData(bytes: dayTotal, base: AppSettings.shared.unitBase)
        let apps = snap?.apps ?? [:]
        let displayItems = formatAppsList(aggregatedApps: apps, grandTotal: dayTotal)
        
        self.screenTimeSummary = ScreenTimeUsageSummary(
            granularity: .day,
            weekOffset: weekOffset,
            dayOffset: dayOffset,
            headerNavTitle: navTitle,
            cardSubtitle: cardSub,
            mainValueFormatted: mainVal,
            trendText: trendText,
            trendIsUp: trendIsUp,
            weekDays: weekBars,
            hourlyUsage: hourly,
            maxDayBytes: maxDay,
            maxHourBytes: maxHour,
            dailyAverageBytes: weekDailyAvg,
            totalBytesIn: dayIn,
            totalBytesOut: dayOut,
            totalBytes: dayTotal,
            appCount: displayItems.count,
            topApps: displayItems,
            lastUpdatedString: updatedStr,
            canGoBack: canGoBack,
            canGoForward: canGoForward
        )
        
        self.summary = DataUsageSummary(
            filter: .day,
            totalBytesIn: dayIn,
            totalBytesOut: dayOut,
            totalBytes: dayTotal,
            appCount: displayItems.count,
            topApps: displayItems,
            dailyBars: []
        )
    }
    
    // MARK: - App Detail Calculation (Week or Day)
    
    public func getAppDetail(appId: String) -> AppDetailUsageData {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = Date()
        
        if granularity == .week {
            // 7 Days breakdown for this specific app (Image 4)
            guard let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now),
                  let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetWeekDate)) else {
                return AppDetailUsageData(appId: appId)
            }
            
            let letterFormatter = DateFormatter()
            letterFormatter.dateFormat = "EEEEE"
            let dayNameFormatter = DateFormatter()
            dayNameFormatter.dateFormat = "EEEE"
            
            var weekBars: [WeekDayBarItem] = []
            var totalIn: UInt64 = 0
            var totalOut: UInt64 = 0
            var appName = appId
            var appBundle: String? = nil
            
            for i in 0..<7 {
                guard let dDate = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
                let dStr = dateFormatter.string(from: dDate)
                let isToday = calendar.isDateInToday(dDate)
                let isFuture = dDate > now && !isToday
                
                let appRecord = storeData.dailyRecords[dStr]?.apps[appId]
                let bIn = isFuture ? 0 : (appRecord?.bytesIn ?? 0)
                let bOut = isFuture ? 0 : (appRecord?.bytesOut ?? 0)
                
                totalIn += bIn
                totalOut += bOut
                
                if let name = appRecord?.displayName, appName == appId {
                    appName = name
                }
                if let bp = appRecord?.bundlePath, appBundle == nil {
                    appBundle = bp
                }
                
                weekBars.append(WeekDayBarItem(
                    date: dDate,
                    dateString: dStr,
                    weekdayLetter: letterFormatter.string(from: dDate),
                    fullDayName: dayNameFormatter.string(from: dDate),
                    bytesIn: bIn,
                    bytesOut: bOut,
                    totalBytes: bIn + bOut,
                    isToday: isToday,
                    isFuture: isFuture,
                    isSelected: false
                ))
            }
            
            let total = totalIn + totalOut
            let weekDaysWithData = weekBars.filter { bar in
                if bar.isFuture { return false }
                if let rec = storeData.dailyRecords[bar.dateString] {
                    return rec.totalBytes > 0
                }
                return bar.totalBytes > 0
            }.count
            let isPastWeek = weekOffset < 0
            let divisor: Int
            if isPastWeek {
                divisor = weekDaysWithData >= 5 ? 7 : max(1, weekDaysWithData)
            } else {
                divisor = max(1, weekDaysWithData)
            }
            let avg = total > 0 ? (total / UInt64(divisor)) : 0
            
            return AppDetailUsageData(
                appId: appId,
                displayName: appName,
                bundlePath: appBundle,
                totalBytes: total,
                bytesIn: totalIn,
                bytesOut: totalOut,
                averageBytes: avg,
                weekBars: weekBars,
                hourlyBars: []
            )
        } else {
            // 24 Hours breakdown for this specific app (Image 2)
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
                return AppDetailUsageData(appId: appId)
            }
            let dStr = dateFormatter.string(from: targetDate)
            let appRecord = storeData.dailyRecords[dStr]?.apps[appId]
            
            let hourly = appRecord?.hourlyUsage ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
            let totalIn = appRecord?.bytesIn ?? 0
            let totalOut = appRecord?.bytesOut ?? 0
            let total = totalIn + totalOut
            
            // Hourly average across the day (adapts to hours elapsed so far if viewing today)
            let isToday = calendar.isDateInToday(targetDate)
            let hoursDivisor: Int
            if isToday {
                hoursDivisor = max(1, calendar.component(.hour, from: now) + 1)
            } else {
                hoursDivisor = 24
            }
            let avg = total > 0 ? (total / UInt64(hoursDivisor)) : 0
            
            let meta = AppInfoResolver.shared.resolve(procKey: appId, pid: nil)
            let appName = (appRecord?.displayName.isEmpty == false) ? appRecord!.displayName : meta.displayName
            let bundlePath = appRecord?.bundlePath ?? meta.bundlePath
            
            return AppDetailUsageData(
                appId: appId,
                displayName: appName,
                bundlePath: bundlePath,
                totalBytes: total,
                bytesIn: totalIn,
                bytesOut: totalOut,
                averageBytes: avg,
                weekBars: [],
                hourlyBars: hourly
            )
        }
    }
    
    private func formatAppsList(aggregatedApps: [String: ProcessUsageRecord], grandTotal: UInt64) -> [AppUsageDisplayItem] {
        var items: [AppUsageDisplayItem] = []
        let maxAppBytes = aggregatedApps.values.map { $0.totalBytes }.max() ?? 0
        
        for record in aggregatedApps.values {
            let itemTotal = record.totalBytes
            guard itemTotal > 0 else { continue }
            
            let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                let match = record.displayName.lowercased().contains(query)
                    || record.id.lowercased().contains(query)
                if !match { continue }
            }
            
            let frac = maxAppBytes > 0 ? Double(itemTotal) / Double(maxAppBytes) : 0.0
            let pct = grandTotal > 0 ? Double(itemTotal) / Double(grandTotal) : 0.0
            
            items.append(AppUsageDisplayItem(
                id: record.id,
                displayName: record.displayName,
                bundlePath: record.bundlePath,
                bytesIn: record.bytesIn,
                bytesOut: record.bytesOut,
                totalBytes: itemTotal,
                fractionOfMax: frac,
                percentage: pct
            ))
        }
        
        items.sort { $0.totalBytes > $1.totalBytes }
        return items
    }
    
    // MARK: - Actions
    
    public func resetToday() {
        let todayKey = dateFormatter.string(from: Date())
        storeData.dailyRecords.removeValue(forKey: todayKey)
        isDirty = true
        saveToDisk()
        recalculateSummary()
    }
    
    public func resetAllHistory() {
        storeData.dailyRecords.removeAll()
        isDirty = true
        saveToDisk()
        recalculateSummary()
    }
    
    // MARK: - Persistence
    
    public func saveToDisk() {
        guard isDirty else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(storeData)
            try data.write(to: fileURL, options: .atomic)
            isDirty = false
        } catch {
            print("Failed to save data usage to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.storeData = try decoder.decode(UsageHistoryStoreData.self, from: data)
        } catch {
            print("Failed to load data usage: \(error)")
        }
    }
}
