import Foundation
import SwiftUI

public enum DisplayMode: String, CaseIterable, Identifiable {
    case stacked = "Two Lines (Stacked)"
    case singleLine = "Single Line (Inline)"
    case downloadOnly = "Download Only"
    case uploadOnly = "Upload Only"
    
    public var id: String { rawValue }
}

public enum DisplayOrder: String, CaseIterable, Identifiable {
    case downloadFirst = "Download First (▼ / ▲)"
    case uploadFirst = "Upload First (▲ / ▼)"
    
    public var id: String { rawValue }
}

public enum ArrowStyle: String, CaseIterable, Identifiable {
    case triangle = "▲ / ▼ (Triangles)"
    case arrow = "↑ / ↓ (Arrows)"
    case letters = "U / D (Letters)"
    case none = "None (Numbers Only)"
    
    public var id: String { rawValue }
    
    public var upSymbol: String {
        switch self {
        case .triangle: return "▲"
        case .arrow: return "↑"
        case .letters: return "U:"
        case .none: return ""
        }
    }
    
    public var downSymbol: String {
        switch self {
        case .triangle: return "▼"
        case .arrow: return "↓"
        case .letters: return "D:"
        case .none: return ""
        }
    }
}

public enum ArrowColorMode: String, CaseIterable, Identifiable {
    case tinted = "Vibrant Colors (Cyan / Amber)"
    case monochrome = "Monochrome (System Theme)"
    
    public var id: String { rawValue }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: "displayMode") }
    }
    
    @Published public var displayOrder: DisplayOrder {
        didSet { defaults.set(displayOrder.rawValue, forKey: "displayOrder") }
    }
    
    @Published public var arrowStyle: ArrowStyle {
        didSet { defaults.set(arrowStyle.rawValue, forKey: "arrowStyle") }
    }
    
    @Published public var colorMode: ArrowColorMode {
        didSet { defaults.set(colorMode.rawValue, forKey: "colorMode") }
    }
    
    @Published public var unitBase: UnitBase {
        didSet { defaults.set(unitBase.rawValue, forKey: "unitBase") }
    }
    
    @Published public var unitNaming: UnitNaming {
        didSet { defaults.set(unitNaming.rawValue, forKey: "unitNaming") }
    }
    
    @Published public var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: "refreshInterval") }
    }
    
    @Published public var selectedInterface: String {
        didSet { defaults.set(selectedInterface, forKey: "selectedInterface") }
    }
    
    @Published public var fixedWidthDigits: Bool {
        didSet { defaults.set(fixedWidthDigits, forKey: "fixedWidthDigits") }
    }
    
    @Published public var isMonitoringEnabled: Bool {
        didSet {
            defaults.set(isMonitoringEnabled, forKey: "isMonitoringEnabled")
            if isMonitoringEnabled {
                NetworkMonitor.shared.resume()
            } else {
                NetworkMonitor.shared.pause()
            }
        }
    }
    
    public init() {
        if defaults.object(forKey: "isMonitoringEnabled") != nil {
            self.isMonitoringEnabled = defaults.bool(forKey: "isMonitoringEnabled")
        } else {
            self.isMonitoringEnabled = true
        }
        if let modeStr = defaults.string(forKey: "displayMode"), let mode = DisplayMode(rawValue: modeStr) {
            self.displayMode = mode
        } else {
            self.displayMode = .stacked
        }
        
        if let orderStr = defaults.string(forKey: "displayOrder"), let order = DisplayOrder(rawValue: orderStr) {
            self.displayOrder = order
        } else {
            self.displayOrder = .downloadFirst
        }
        
        if let arrowStr = defaults.string(forKey: "arrowStyle"), let arrow = ArrowStyle(rawValue: arrowStr) {
            self.arrowStyle = arrow
        } else {
            self.arrowStyle = .triangle
        }
        
        if let colorStr = defaults.string(forKey: "colorMode"), let color = ArrowColorMode(rawValue: colorStr) {
            self.colorMode = color
        } else {
            self.colorMode = .tinted
        }
        
        if let baseStr = defaults.string(forKey: "unitBase"), let base = UnitBase(rawValue: baseStr) {
            self.unitBase = base
        } else {
            self.unitBase = .binary1024
        }
        
        if let nameStr = defaults.string(forKey: "unitNaming"), let naming = UnitNaming(rawValue: nameStr) {
            self.unitNaming = naming
        } else {
            self.unitNaming = .standard
        }
        
        let interval = defaults.double(forKey: "refreshInterval")
        self.refreshInterval = (interval >= 0.5 && interval <= 5.0) ? interval : 1.0
        
        self.selectedInterface = defaults.string(forKey: "selectedInterface") ?? "all"
        
        if defaults.object(forKey: "fixedWidthDigits") != nil {
            self.fixedWidthDigits = defaults.bool(forKey: "fixedWidthDigits")
        } else {
            self.fixedWidthDigits = true
        }
    }
}
