import AppKit
import Combine

/// AppKit exception: the status item shows two stacked lines of 8.5pt text, which
/// `MenuBarExtra`'s label cannot lay out (unverified; re-check if this is ever migrated).
/// Colors are system colors only so it follows light/dark, accent and highlight state.
public final class MenuBarView: NSView {
    private weak var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    private var downFormatted: FormattedSpeed = SpeedFormatter.format(bytesPerSecond: 0)
    private var upFormatted: FormattedSpeed = SpeedFormatter.format(bytesPerSecond: 0)
    
    public init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        super.init(frame: NSRect(x: 0, y: 0, width: 68, height: NSStatusBar.system.thickness))
        
        setupSubscriptions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    
    private func setupSubscriptions() {
        let stats = NetworkStats.shared
        let settings = AppSettings.shared
        
        Publishers.CombineLatest(stats.$downloadSpeed, stats.$uploadSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] down, up in
                self?.updateSpeeds(down: down, up: up)
            }
            .store(in: &cancellables)
            
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLayout()
            }
            .store(in: &cancellables)
    }
    
    public func updateSpeeds(down: Double, up: Double) {
        let settings = AppSettings.shared
        downFormatted = SpeedFormatter.format(
            bytesPerSecond: down,
            base: settings.unitBase,
            naming: settings.unitNaming,
            padDigits: settings.fixedWidthDigits
        )
        upFormatted = SpeedFormatter.format(
            bytesPerSecond: up,
            base: settings.unitBase,
            naming: settings.unitNaming,
            padDigits: settings.fixedWidthDigits
        )
        
        // Fast redraw without changing dimensions
        needsDisplay = true
    }
    
    override public var intrinsicContentSize: NSSize {
        return NSSize(width: calculateWidth(), height: NSStatusBar.system.thickness)
    }
    
    public func refreshLayout() {
        let newWidth = calculateWidth()
        invalidateIntrinsicContentSize()
        if abs(frame.width - newWidth) > 0.5 {
            frame.size.width = newWidth
            statusItem?.length = newWidth
        }
        needsDisplay = true
    }
    
    /// Stable, fixed width per display mode to prevent any horizontal jittering or popover movement
    private func calculateWidth() -> CGFloat {
        let settings = AppSettings.shared
        switch settings.displayMode {
        case .stacked:
            return 68.0
        case .singleLine:
            return 138.0
        case .downloadOnly, .uploadOnly:
            return 72.0
        }
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let settings = AppSettings.shared
        let isHighlighted = (statusItem?.button?.isHighlighted ?? false)
        
        // Colors
        let textColor: NSColor
        let downArrowColor: NSColor
        let upArrowColor: NSColor
        
        if isHighlighted {
            textColor = .selectedMenuItemTextColor
            downArrowColor = .selectedMenuItemTextColor
            upArrowColor = .selectedMenuItemTextColor
        } else {
            textColor = NSColor.labelColor
            if settings.colorMode == .tinted {
                downArrowColor = NSColor.systemBlue
                upArrowColor = NSColor.systemOrange
            } else {
                downArrowColor = NSColor.secondaryLabelColor
                upArrowColor = NSColor.secondaryLabelColor
            }
        }
        
        if !settings.isMonitoringEnabled {
            let pausedFont = NSFont.systemFont(ofSize: 10, weight: .medium)
            let pausedAttrs: [NSAttributedString.Key: Any] = [
                .font: pausedFont,
                .foregroundColor: isHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
            ]
            let str = "Paused" as NSString
            let size = str.size(withAttributes: pausedAttrs)
            let pt = NSPoint(x: round((bounds.width - size.width) / 2), y: round((bounds.height - size.height) / 2))
            str.draw(at: pt, withAttributes: pausedAttrs)
            return
        }
        
        switch settings.displayMode {
        case .stacked:
            drawStacked(
                settings: settings,
                textColor: textColor,
                downArrowColor: downArrowColor,
                upArrowColor: upArrowColor
            )
        case .singleLine:
            drawSingleLine(
                settings: settings,
                textColor: textColor,
                downArrowColor: downArrowColor,
                upArrowColor: upArrowColor
            )
        case .downloadOnly:
            drawSingleStat(
                symbol: settings.arrowStyle.downSymbol,
                formatted: downFormatted,
                arrowColor: downArrowColor,
                textColor: textColor
            )
        case .uploadOnly:
            drawSingleStat(
                symbol: settings.arrowStyle.upSymbol,
                formatted: upFormatted,
                arrowColor: upArrowColor,
                textColor: textColor
            )
        }
    }
    
    private func drawStacked(
        settings: AppSettings,
        textColor: NSColor,
        downArrowColor: NSColor,
        upArrowColor: NSColor
    ) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        let arrowFont = NSFont.systemFont(ofSize: 7.5, weight: .bold)
        
        // Line 1 is Top, Line 2 is Bottom
        let line1Symbol: String
        let line1Formatted: FormattedSpeed
        let line1ArrowColor: NSColor
        
        let line2Symbol: String
        let line2Formatted: FormattedSpeed
        let line2ArrowColor: NSColor
        
        // "Top it should be download should be first."
        if settings.displayOrder == .downloadFirst {
            line1Symbol = settings.arrowStyle.downSymbol
            line1Formatted = downFormatted
            line1ArrowColor = downArrowColor
            
            line2Symbol = settings.arrowStyle.upSymbol
            line2Formatted = upFormatted
            line2ArrowColor = upArrowColor
        } else {
            line1Symbol = settings.arrowStyle.upSymbol
            line1Formatted = upFormatted
            line1ArrowColor = upArrowColor
            
            line2Symbol = settings.arrowStyle.downSymbol
            line2Formatted = downFormatted
            line2ArrowColor = downArrowColor
        }
        
        let leftMargin: CGFloat = 3
        let rightMargin: CGFloat = bounds.width - 3
        
        // Exact vertical positioning within 22pt status bar height
        let line1Y: CGFloat = bounds.height - 10.5
        let line2Y: CGFloat = 1.5
        
        // Line 1: Arrow on left
        if !line1Symbol.isEmpty {
            let arrowAttrs: [NSAttributedString.Key: Any] = [.font: arrowFont, .foregroundColor: line1ArrowColor]
            (line1Symbol as NSString).draw(at: NSPoint(x: leftMargin, y: line1Y + 0.5), withAttributes: arrowAttrs)
        }
        // Line 1: Text right-aligned
        let textAttrs1: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let line1TextWidth = (line1Formatted.fullString as NSString).size(withAttributes: textAttrs1).width
        let line1TextX = max(leftMargin + 10, rightMargin - line1TextWidth)
        (line1Formatted.fullString as NSString).draw(at: NSPoint(x: line1TextX, y: line1Y), withAttributes: textAttrs1)
        
        // Line 2: Arrow on left
        if !line2Symbol.isEmpty {
            let arrowAttrs: [NSAttributedString.Key: Any] = [.font: arrowFont, .foregroundColor: line2ArrowColor]
            (line2Symbol as NSString).draw(at: NSPoint(x: leftMargin, y: line2Y + 0.5), withAttributes: arrowAttrs)
        }
        // Line 2: Text right-aligned
        let textAttrs2: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let line2TextWidth = (line2Formatted.fullString as NSString).size(withAttributes: textAttrs2).width
        let line2TextX = max(leftMargin + 10, rightMargin - line2TextWidth)
        (line2Formatted.fullString as NSString).draw(at: NSPoint(x: line2TextX, y: line2Y), withAttributes: textAttrs2)
    }
    
    private func drawSingleLine(
        settings: AppSettings,
        textColor: NSColor,
        downArrowColor: NSColor,
        upArrowColor: NSColor
    ) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        let arrowFont = NSFont.systemFont(ofSize: 10, weight: .bold)
        
        var curX: CGFloat = 4
        let textHeight: CGFloat = (downFormatted.fullString as NSString).size(withAttributes: [.font: font]).height
        let yPos: CGFloat = round((bounds.height - textHeight) / 2)
        
        let firstSymbol: String
        let firstFormatted: FormattedSpeed
        let firstArrowColor: NSColor
        
        let secondSymbol: String
        let secondFormatted: FormattedSpeed
        let secondArrowColor: NSColor
        
        if settings.displayOrder == .downloadFirst {
            firstSymbol = settings.arrowStyle.downSymbol
            firstFormatted = downFormatted
            firstArrowColor = downArrowColor
            
            secondSymbol = settings.arrowStyle.upSymbol
            secondFormatted = upFormatted
            secondArrowColor = upArrowColor
        } else {
            firstSymbol = settings.arrowStyle.upSymbol
            firstFormatted = upFormatted
            firstArrowColor = upArrowColor
            
            secondSymbol = settings.arrowStyle.downSymbol
            secondFormatted = downFormatted
            secondArrowColor = downArrowColor
        }
        
        // Item 1
        if !firstSymbol.isEmpty {
            let arrowAttrs: [NSAttributedString.Key: Any] = [.font: arrowFont, .foregroundColor: firstArrowColor]
            (firstSymbol as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: arrowAttrs)
            curX += (firstSymbol as NSString).size(withAttributes: arrowAttrs).width + 2
        }
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        (firstFormatted.fullString as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: textAttrs)
        curX += (firstFormatted.fullString as NSString).size(withAttributes: textAttrs).width + 8
        
        // Item 2
        if !secondSymbol.isEmpty {
            let arrowAttrs: [NSAttributedString.Key: Any] = [.font: arrowFont, .foregroundColor: secondArrowColor]
            (secondSymbol as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: arrowAttrs)
            curX += (secondSymbol as NSString).size(withAttributes: arrowAttrs).width + 2
        }
        (secondFormatted.fullString as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: textAttrs)
    }
    
    private func drawSingleStat(
        symbol: String,
        formatted: FormattedSpeed,
        arrowColor: NSColor,
        textColor: NSColor
    ) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        let arrowFont = NSFont.systemFont(ofSize: 10, weight: .bold)
        
        var curX: CGFloat = 4
        let textHeight: CGFloat = (formatted.fullString as NSString).size(withAttributes: [.font: font]).height
        let yPos: CGFloat = round((bounds.height - textHeight) / 2)
        
        if !symbol.isEmpty {
            let arrowAttrs: [NSAttributedString.Key: Any] = [.font: arrowFont, .foregroundColor: arrowColor]
            (symbol as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: arrowAttrs)
            curX += (symbol as NSString).size(withAttributes: arrowAttrs).width + 2
        }
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        (formatted.fullString as NSString).draw(at: NSPoint(x: curX, y: yPos), withAttributes: textAttrs)
    }
}

import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 10) {
            // Header: Network connection
            HStack {
                let isWifi = stats.activeInterfaceBSD.hasPrefix("en")
                Image(systemName: isWifi ? "wifi" : "network")
                Text(stats.activeWiFiSSID ?? stats.activeInterfaceName)
                    .font(.headline)
                Spacer()
                Text(stats.localIP)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider().padding(.horizontal, 12)
            
            // Speed containers (side by side)
            HStack(spacing: 8) {
                SpeedContainer(
                    title: "Download", 
                    icon: "arrow.down.circle.fill",
                    color: Semantic.download,
                    speed: stats.downloadSpeed,
                    peak: stats.peakDownloadSpeed
                )
                
                SpeedContainer(
                    title: "Upload", 
                    icon: "arrow.up.circle.fill",
                    color: Semantic.upload,
                    speed: stats.uploadSpeed,
                    peak: stats.peakUploadSpeed
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Divider().padding(.horizontal, 12)
            
            // Menu actions
            VStack(spacing: 2) {
                MenuButton(title: "Open Network Speed…", icon: "speedometer", shortcut: "o") {
                    AppDelegate.shared?.openDashboard()
                    AppDelegate.shared?.closePopover()
                }
                
                MenuButton(title: "Settings…", icon: "gearshape", shortcut: ",") {
                    AppDelegate.shared?.openSettings()
                    AppDelegate.shared?.closePopover()
                }
                
                Divider().padding(.vertical, 4).padding(.horizontal, 6)
                
                MenuButton(title: "Quit Network Speed", icon: "xmark.circle") {
                    AppDelegate.shared?.quitApp()
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 260)
    }
}

private struct SpeedContainer: View {
    let title: String
    let icon: String
    let color: Color
    let speed: Double
    let peak: Double
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            let speedStr = SpeedFormatter.format(bytesPerSecond: speed, base: settings.unitBase, naming: settings.unitNaming).fullString
            Text(speedStr)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundColor(.primary)
            
            let peakStr = SpeedFormatter.format(bytesPerSecond: peak, base: settings.unitBase, naming: settings.unitNaming).fullString
            Text("Peak: \(peakStr)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
                if let shortcut {
                    Text("⌘\(shortcut.uppercased())")
                        .font(.caption)
                        .foregroundColor(isHovered ? .white.opacity(0.8) : .secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isHovered ? Color.accentColor : Color.clear)
            .foregroundColor(isHovered ? .white : .primary)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .modifier(OptionalShortcutModifier(shortcut: shortcut))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct OptionalShortcutModifier: ViewModifier {
    let shortcut: String?
    
    func body(content: Content) -> some View {
        if let shortcut, let char = shortcut.first {
            content.keyboardShortcut(KeyEquivalent(char), modifiers: .command)
        } else {
            content
        }
    }
}
