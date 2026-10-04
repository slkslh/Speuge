import SwiftUI
import AppKit

public struct PopoverView: View {
    @ObservedObject var stats = NetworkStats.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var isSettingsActive: Bool = false
    @State private var isInterfacesActive: Bool = false
    @State private var copiedIP: Bool = false
    @State private var isLaunchAtLogin: Bool = LaunchAtLogin.isEnabled
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Top Header: Title + Master Switch or Back Button
            headerBar
            
            Divider()
                .opacity(0.25)
                .padding(.horizontal, 2)
            
            if isSettingsActive {
                settingsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else if isInterfacesActive {
                interfacesView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                overviewView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 15)
        .frame(width: 330, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            if isSettingsActive || isInterfacesActive {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSettingsActive = false
                        isInterfacesActive = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Network Speed")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(isSettingsActive ? "Settings" : "All Interfaces")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            } else {
                Text("Network Speed")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Master Toggle Switch (Native Apple style matching Wi-Fi toggle)
                Toggle("", isOn: $settings.isMonitoringEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 28)
    }
    
    // MARK: - Overview View (Real Apple Wi-Fi Style)
    
    private var overviewView: some View {
        VStack(spacing: 8) {
            // 1. ACTIVE CONNECTION (Like Known Networks in Apple Wi-Fi)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ACTIVE CONNECTION")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stats.isConnected && settings.isMonitoringEnabled ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(settings.isMonitoringEnabled ? (stats.isConnected ? "Connected" : "Offline") : "Paused")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                
                // Active Connection Row
                HStack(spacing: 10) {
                    // Blue circular badge with Wi-Fi / Ethernet symbol
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 28, height: 28)
                        Image(systemName: stats.activeInterfaceBSD.hasPrefix("en") ? "wifi" : "cable.connector")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    let cleanName: String = {
                        let raw = stats.activeInterfaceName.trimmingCharacters(in: .whitespaces)
                        if !raw.isEmpty && !raw.hasPrefix("<") && raw != "<redacted>" {
                            return raw
                        }
                        return "Wi-Fi"
                    }()
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cleanName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(stats.localIP, forType: .string)
                            copiedIP = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedIP = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(copiedIP ? "Copied IP to Clipboard" : "IP: \(stats.localIP)")
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 8.5))
                            }
                            .foregroundColor(copiedIP ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Click to copy local IP address")
                    }
                    
                    Spacer()
                    
                    if stats.isConnected && settings.isMonitoringEnabled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            
            // 2. DATA TRANSFER (Download & Upload Rows)
            VStack(alignment: .leading, spacing: 4) {
                Text("DATA TRANSFER")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    speedRow(
                        title: "Download",
                        symbol: "arrow.down",
                        circleColor: Color.blue,
                        speed: stats.downloadSpeed,
                        peak: stats.peakDownloadSpeed,
                        total: stats.sessionDownloadedBytes
                    )
                    
                    Divider()
                        .opacity(0.15)
                        .padding(.leading, 46)
                        .padding(.trailing, 8)
                    
                    speedRow(
                        title: "Upload",
                        symbol: "arrow.up",
                        circleColor: Color.orange,
                        speed: stats.uploadSpeed,
                        peak: stats.peakUploadSpeed,
                        total: stats.sessionUploadedBytes
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            
            // 3. ACTIVITY CHART
            LiveHistoryChart(history: stats.history, base: settings.unitBase)
            
            // 4. ALL INTERFACES (Clean navigation to detail subpage, matching Apple Wi-Fi)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isInterfacesActive = true
                }
            }) {
                HStack {
                    Text("All Interfaces")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppleHoverButtonStyle())
            
            Divider()
                .opacity(0.25)
                .padding(.horizontal, 2)
            
            // 5. BOTTOM ACTION (Exact match to "Wi-Fi Settings..." in Image 2!)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSettingsActive = true
                }
            }) {
                HStack {
                    Text("Network Speed Settings…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppleHoverButtonStyle())
        }
    }
    
    // MARK: - All Interfaces Detail View (Native Apple Style)
    
    private var interfacesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NETWORK INTERFACES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(stats.availableInterfaces.prefix(5).enumerated()), id: \.element.id) { index, intf in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(intf.isPrimary ? Color.blue : Color.primary.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: intf.bsdName.hasPrefix("en") ? "wifi" : "network")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(intf.isPrimary ? .white : .secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(intf.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if intf.isPrimary {
                                    Text("Primary")
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text("BSD: \(intf.bsdName)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if intf.isPrimary {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    
                    if index < min(stats.availableInterfaces.count, 5) - 1 {
                        Divider()
                            .opacity(0.15)
                            .padding(.leading, 48)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            
            Spacer()
        }
    }
    
    // MARK: - Speed Row Helper
    
    private func speedRow(
        title: String,
        symbol: String,
        circleColor: Color,
        speed: Double,
        peak: Double,
        total: UInt64
    ) -> some View {
        let formatted = SpeedFormatter.format(
            bytesPerSecond: speed,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let peakFormatted = SpeedFormatter.format(
            bytesPerSecond: peak,
            base: settings.unitBase,
            naming: settings.unitNaming
        )
        let totalFormatted = SpeedFormatter.formatData(
            bytes: total,
            base: settings.unitBase
        )
        
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 28, height: 28)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Peak: \(peakFormatted.fullString)")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("Total: \(totalFormatted)")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(settings.isMonitoringEnabled ? formatted.valueString : "--")
                    .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(settings.isMonitoringEnabled ? formatted.unitString : "")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    // MARK: - Settings View (Apple System Settings Style)
    
    private var settingsView: some View {
        VStack(spacing: 8) {
            // Group 1: Menu Bar Display Preferences
            VStack(alignment: .leading, spacing: 3) {
                Text("MENU BAR")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    settingRow(label: "Menu Bar Style") {
                        Picker("", selection: $settings.displayMode) {
                            ForEach(DisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    Divider().opacity(0.15).padding(.horizontal, 8)
                    
                    settingRow(label: "Display Order") {
                        Picker("", selection: $settings.displayOrder) {
                            ForEach(DisplayOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    Divider().opacity(0.15).padding(.horizontal, 8)
                    
                    settingRow(label: "Indicator Style") {
                        Picker("", selection: $settings.arrowStyle) {
                            ForEach(ArrowStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            
            // Group 2: General Preferences
            VStack(alignment: .leading, spacing: 3) {
                Text("GENERAL")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    settingRow(label: "Update Frequency") {
                        Picker("", selection: $settings.refreshInterval) {
                            Text("0.5s (Fast)").tag(0.5)
                            Text("1.0s (Normal)").tag(1.0)
                            Text("2.0s (Eco)").tag(2.0)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .onChange(of: settings.refreshInterval) { _ in
                            NetworkMonitor.shared.updateInterval()
                        }
                    }
                    
                    Divider().opacity(0.15).padding(.horizontal, 8)
                    
                    settingRow(label: "Unit Standard") {
                        Picker("", selection: $settings.unitBase) {
                            ForEach(UnitBase.allCases) { base in
                                Text(base.rawValue).tag(base)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    Divider().opacity(0.15).padding(.horizontal, 8)
                    
                    settingRow(label: "Interface") {
                        Picker("", selection: $settings.selectedInterface) {
                            Text("All Active").tag("all")
                            Text("Auto (Primary)").tag("auto")
                            Divider()
                            ForEach(stats.availableInterfaces) { intf in
                                Text(intf.displayName).tag(intf.bsdName)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .onChange(of: settings.selectedInterface) { _ in
                            NetworkMonitor.shared.updateInterval()
                        }
                    }
                    
                    Divider().opacity(0.15).padding(.horizontal, 8)
                    
                    HStack {
                        Text("Launch at Login")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                        Spacer()
                        Toggle("", isOn: $isLaunchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: isLaunchAtLogin) { val in
                                LaunchAtLogin.isEnabled = val
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            
            Divider()
                .opacity(0.25)
                .padding(.horizontal, 2)
            
            // Bottom Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    stats.resetSession()
                }) {
                    Text("Reset All Statistics")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AppleHoverButtonStyle())
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit Network Speed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AppleHoverButtonStyle())
            }
        }
    }
    
    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Native Apple Hover Button Style

struct AppleHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
