import Foundation
import SwiftUI
import AppKit

public enum UsageGranularity: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case week = "Week"
    
    public var id: String { rawValue }
}

public enum UsageTimeFilter: String, CaseIterable, Identifiable, Sendable {
    case day = "Today"
    case week = "7 Days"
    case month = "30 Days"
    case allTime = "All Time"
    
    public var id: String { rawValue }
}

/// Usage record for a single hour of the day (0 ... 23)
public struct HourlyUsageRecord: Codable, Identifiable, Sendable {
    public var id: Int { hour }
    public var hour: Int // 0 ... 23
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    
    public var totalBytes: UInt64 {
        bytesIn + bytesOut
    }
    
    public init(hour: Int, bytesIn: UInt64 = 0, bytesOut: UInt64 = 0) {
        self.hour = hour
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

/// Persistent record for a single process or application on a given day
public struct ProcessUsageRecord: Codable, Identifiable, Sendable {
    public var id: String // Bundle ID (e.g. com.google.Chrome) or process name
    public var displayName: String
    public var bundlePath: String?
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var lastSeen: Date
    public var hourlyUsage: [HourlyUsageRecord]
    
    public var totalBytes: UInt64 {
        bytesIn + bytesOut
    }
    
    public init(
        id: String,
        displayName: String,
        bundlePath: String? = nil,
        bytesIn: UInt64 = 0,
        bytesOut: UInt64 = 0,
        lastSeen: Date = Date(),
        hourlyUsage: [HourlyUsageRecord]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bundlePath = bundlePath
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.lastSeen = lastSeen
        self.hourlyUsage = hourlyUsage ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, displayName, bundlePath, bytesIn, bytesOut, lastSeen, hourlyUsage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        self.bytesIn = try container.decode(UInt64.self, forKey: .bytesIn)
        self.bytesOut = try container.decode(UInt64.self, forKey: .bytesOut)
        self.lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        self.hourlyUsage = try container.decodeIfPresent([HourlyUsageRecord].self, forKey: .hourlyUsage)
            ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
    }
}

/// Snapshot of all data usage for one specific day (YYYY-MM-DD)
public struct DailyUsageSnapshot: Codable, Identifiable, Sendable {
    public var id: String { dateString }
    public var dateString: String // Format: YYYY-MM-DD
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64
    public var apps: [String: ProcessUsageRecord]
    public var hourlyUsage: [HourlyUsageRecord]
    
    public var totalBytes: UInt64 {
        totalBytesIn + totalBytesOut
    }
    
    public init(
        dateString: String,
        totalBytesIn: UInt64 = 0,
        totalBytesOut: UInt64 = 0,
        apps: [String: ProcessUsageRecord] = [:],
        hourlyUsage: [HourlyUsageRecord]? = nil
    ) {
        self.dateString = dateString
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.apps = apps
        self.hourlyUsage = hourlyUsage ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case dateString, totalBytesIn, totalBytesOut, apps, hourlyUsage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dateString = try container.decode(String.self, forKey: .dateString)
        self.totalBytesIn = try container.decode(UInt64.self, forKey: .totalBytesIn)
        self.totalBytesOut = try container.decode(UInt64.self, forKey: .totalBytesOut)
        self.apps = try container.decodeIfPresent([String: ProcessUsageRecord].self, forKey: .apps) ?? [:]
        self.hourlyUsage = try container.decodeIfPresent([HourlyUsageRecord].self, forKey: .hourlyUsage)
            ?? (0..<24).map { HourlyUsageRecord(hour: $0) }
    }
}

/// Root data model persisted to disk (JSON)
public struct UsageHistoryStoreData: Codable, Sendable {
    public var version: Int = 1
    public var dailyRecords: [String: DailyUsageSnapshot] = [:]
    
    public init(version: Int = 1, dailyRecords: [String: DailyUsageSnapshot] = [:]) {
        self.version = version
        self.dailyRecords = dailyRecords
    }
}

/// Single bar item for the 7-day Screen Time chart (Monday to Sunday)
public struct WeekDayBarItem: Identifiable, Sendable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String
    public let weekdayLetter: String // "M", "T", "W", "T", "F", "S", "S"
    public let fullDayName: String   // "Monday", "Tuesday", etc.
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let totalBytes: UInt64
    public let isToday: Bool
    public let isFuture: Bool
    public let isSelected: Bool
    
    public init(
        date: Date,
        dateString: String,
        weekdayLetter: String,
        fullDayName: String,
        bytesIn: UInt64,
        bytesOut: UInt64,
        totalBytes: UInt64,
        isToday: Bool,
        isFuture: Bool,
        isSelected: Bool = false
    ) {
        self.date = date
        self.dateString = dateString
        self.weekdayLetter = weekdayLetter
        self.fullDayName = fullDayName
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.totalBytes = totalBytes
        self.isToday = isToday
        self.isFuture = isFuture
        self.isSelected = isSelected
    }
}

/// UI display item for an app row matching Apple Screen Time style
public struct AppUsageDisplayItem: Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var bundlePath: String?
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var totalBytes: UInt64
    public var fractionOfMax: Double // 0.0 ... 1.0 (relative to most used app)
    public var percentage: Double    // 0.0 ... 1.0 (percentage of total)
    
    public init(
        id: String,
        displayName: String,
        bundlePath: String?,
        bytesIn: UInt64,
        bytesOut: UInt64,
        totalBytes: UInt64,
        fractionOfMax: Double = 0.0,
        percentage: Double = 0.0
    ) {
        self.id = id
        self.displayName = displayName
        self.bundlePath = bundlePath
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.totalBytes = totalBytes
        self.fractionOfMax = fractionOfMax
        self.percentage = percentage
    }
}

/// Single bar item for generic timeline fallback
public struct DailyBarItem: Identifiable, Sendable {
    public var id: String { dateString }
    public var date: Date
    public var dateString: String
    public var dayLabel: String
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var totalBytes: UInt64
    
    public init(
        date: Date,
        dateString: String,
        dayLabel: String,
        bytesIn: UInt64,
        bytesOut: UInt64,
        totalBytes: UInt64
    ) {
        self.date = date
        self.dateString = dateString
        self.dayLabel = dayLabel
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.totalBytes = totalBytes
    }
}

/// App Detail Data for Detail View (Week or Day)
public struct AppDetailUsageData: Sendable {
    public var appId: String
    public var displayName: String
    public var bundlePath: String?
    public var totalBytes: UInt64
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var averageBytes: UInt64
    public var weekBars: [WeekDayBarItem]
    public var hourlyBars: [HourlyUsageRecord]
    
    public init(
        appId: String = "",
        displayName: String = "",
        bundlePath: String? = nil,
        totalBytes: UInt64 = 0,
        bytesIn: UInt64 = 0,
        bytesOut: UInt64 = 0,
        averageBytes: UInt64 = 0,
        weekBars: [WeekDayBarItem] = [],
        hourlyBars: [HourlyUsageRecord] = []
    ) {
        self.appId = appId
        self.displayName = displayName
        self.bundlePath = bundlePath
        self.totalBytes = totalBytes
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.averageBytes = averageBytes
        self.weekBars = weekBars
        self.hourlyBars = hourlyBars
    }
}

/// Summary matching Apple Screen Time layout
public struct ScreenTimeUsageSummary: Sendable {
    public var granularity: UsageGranularity
    public var weekOffset: Int
    public var dayOffset: Int
    
    public var headerNavTitle: String
    public var cardSubtitle: String
    public var mainValueFormatted: String
    public var trendText: String?
    public var trendIsUp: Bool?
    
    public var weekDays: [WeekDayBarItem]
    public var hourlyUsage: [HourlyUsageRecord]
    public var maxDayBytes: UInt64
    public var maxHourBytes: UInt64
    public var dailyAverageBytes: UInt64
    
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64
    public var totalBytes: UInt64
    public var appCount: Int
    
    public var topApps: [AppUsageDisplayItem]
    public var lastUpdatedString: String
    
    public var canGoBack: Bool
    public var canGoForward: Bool
    
    public init(
        granularity: UsageGranularity = .week,
        weekOffset: Int = 0,
        dayOffset: Int = 0,
        headerNavTitle: String = "This Week",
        cardSubtitle: String = "Daily Average",
        mainValueFormatted: String = "0 B",
        trendText: String? = nil,
        trendIsUp: Bool? = nil,
        weekDays: [WeekDayBarItem] = [],
        hourlyUsage: [HourlyUsageRecord] = [],
        maxDayBytes: UInt64 = 0,
        maxHourBytes: UInt64 = 0,
        dailyAverageBytes: UInt64 = 0,
        totalBytesIn: UInt64 = 0,
        totalBytesOut: UInt64 = 0,
        totalBytes: UInt64 = 0,
        appCount: Int = 0,
        topApps: [AppUsageDisplayItem] = [],
        lastUpdatedString: String = "Updated today",
        canGoBack: Bool = true,
        canGoForward: Bool = false
    ) {
        self.granularity = granularity
        self.weekOffset = weekOffset
        self.dayOffset = dayOffset
        self.headerNavTitle = headerNavTitle
        self.cardSubtitle = cardSubtitle
        self.mainValueFormatted = mainValueFormatted
        self.trendText = trendText
        self.trendIsUp = trendIsUp
        self.weekDays = weekDays
        self.hourlyUsage = hourlyUsage
        self.maxDayBytes = maxDayBytes
        self.maxHourBytes = maxHourBytes
        self.dailyAverageBytes = dailyAverageBytes
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.totalBytes = totalBytes
        self.appCount = appCount
        self.topApps = topApps
        self.lastUpdatedString = lastUpdatedString
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}

/// Backward compatibility summary
public struct DataUsageSummary: Sendable {
    public var filter: UsageTimeFilter
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64
    public var totalBytes: UInt64
    public var appCount: Int
    public var topApps: [AppUsageDisplayItem]
    public var dailyBars: [DailyBarItem]
    
    public init(
        filter: UsageTimeFilter = .day,
        totalBytesIn: UInt64 = 0,
        totalBytesOut: UInt64 = 0,
        totalBytes: UInt64 = 0,
        appCount: Int = 0,
        topApps: [AppUsageDisplayItem] = [],
        dailyBars: [DailyBarItem] = []
    ) {
        self.filter = filter
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.totalBytes = totalBytes
        self.appCount = appCount
        self.topApps = topApps
        self.dailyBars = dailyBars
    }
}
