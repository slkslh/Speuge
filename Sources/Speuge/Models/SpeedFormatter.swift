import Foundation

public struct FormattedSpeed {
    public let valueString: String
    public let unitString: String
    public let fullString: String
    public let rawBytes: Double
    
    public init(valueString: String, unitString: String, fullString: String, rawBytes: Double) {
        self.valueString = valueString
        self.unitString = unitString
        self.fullString = fullString
        self.rawBytes = rawBytes
    }
}

public enum UnitBase: String, CaseIterable, Identifiable {
    case binary1024 = "1024 (Binary)"
    case decimal1000 = "1000 (Decimal)"
    
    public var id: String { rawValue }
    public var multiplier: Double {
        switch self {
        case .binary1024: return 1024.0
        case .decimal1000: return 1000.0
        }
    }
}

public enum UnitNaming: String, CaseIterable, Identifiable {
    case standard = "KB/s, MB/s, GB/s"
    case iec = "KiB/s, MiB/s, GiB/s"
    case compact = "K, M, G"
    
    public var id: String { rawValue }
}

public enum SpeedFormatter {
    
    /// Formats bytes per second into human-readable rate
    public static func format(
        bytesPerSecond: Double,
        base: UnitBase = .binary1024,
        naming: UnitNaming = .standard,
        padDigits: Bool = false
    ) -> FormattedSpeed {
        guard bytesPerSecond > 0 && !bytesPerSecond.isNaN && !bytesPerSecond.isInfinite else {
            let zeroUnit: String
            switch naming {
            case .standard: zeroUnit = "B/s"
            case .iec: zeroUnit = "B/s"
            case .compact: zeroUnit = "B"
            }
            let val = padDigits ? "  0" : "0"
            return FormattedSpeed(
                valueString: val,
                unitString: zeroUnit,
                fullString: "\(val) \(zeroUnit)",
                rawBytes: 0
            )
        }
        
        let step = base.multiplier
        let units: [String]
        switch naming {
        case .standard:
            units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        case .iec:
            units = ["B/s", "KiB/s", "MiB/s", "GiB/s", "TiB/s"]
        case .compact:
            units = ["B", "K", "M", "G", "T"]
        }
        
        var val = bytesPerSecond
        var unitIndex = 0
        
        while val >= step && unitIndex < units.count - 1 {
            val /= step
            unitIndex += 1
        }
        
        let valStr: String
        if unitIndex == 0 {
            // Bytes: integer only
            valStr = padDigits ? String(format: "%3.0f", val) : String(format: "%.0f", val)
        } else if val < 10 {
            // Single digit: 2 decimals, e.g. 4.25 MB/s
            valStr = padDigits ? String(format: "%4.2f", val) : String(format: "%.2f", val)
        } else if val < 100 {
            // Two digits: 1 decimal, e.g. 45.2 KB/s
            valStr = padDigits ? String(format: "%4.1f", val) : String(format: "%.1f", val)
        } else {
            // Three digits: 0 or 1 decimal, e.g. 250 KB/s
            valStr = padDigits ? String(format: "%3.0f", val) : String(format: "%.0f", val)
        }
        
        let unitStr = units[unitIndex]
        return FormattedSpeed(
            valueString: valStr,
            unitString: unitStr,
            fullString: "\(valStr) \(unitStr)",
            rawBytes: bytesPerSecond
        )
    }
    
    /// Formats total data transferred (e.g. 1.45 GB, 250 MB)
    public static func formatData(bytes: UInt64, base: UnitBase = .binary1024) -> String {
        let step = base.multiplier
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var val = Double(bytes)
        var unitIndex = 0
        
        while val >= step && unitIndex < units.count - 1 {
            val /= step
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(bytes) B"
        } else if val < 10 {
            return String(format: "%.2f %@", val, units[unitIndex])
        } else if val < 100 {
            return String(format: "%.1f %@", val, units[unitIndex])
        } else {
            return String(format: "%.1f %@", val, units[unitIndex])
        }
    }
}
