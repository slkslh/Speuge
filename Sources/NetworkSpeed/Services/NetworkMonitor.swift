import Foundation
import Network
import SystemConfiguration
import Darwin
import QuartzCore
import CoreWLAN
import CoreLocation

public final class NetworkMonitor: @unchecked Sendable {
    public static let shared = NetworkMonitor()
    
    private var locationManager: CLLocationManager?
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.networkspeed.pathmonitor")
    private let sampleQueue = DispatchQueue(label: "com.networkspeed.sampler", qos: .userInteractive)
    
    private var timer: DispatchSourceTimer?
    
    private var lastTime: Double = 0
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var isFirstSample: Bool = true
    
    private var primaryInterfaceBSD: String = "en0"
    
    private init() {}
    
    public func start() {
        setupPathMonitor()
        refreshInterfacesList()
        startSamplingTimer()
    }
    
    public func stop() {
        timer?.cancel()
        timer = nil
        pathMonitor.cancel()
    }
    
    public func pause() {
        timer?.cancel()
        timer = nil
        isFirstSample = true
        lastTime = 0
        Task { @MainActor in
            NetworkStats.shared.downloadSpeed = 0
            NetworkStats.shared.uploadSpeed = 0
        }
    }
    
    public func resume() {
        startSamplingTimer()
    }
    
    public func updateInterval() {
        startSamplingTimer()
    }
    
    // MARK: - Path Monitor
    
    private func setupPathMonitor() {
        Task { @MainActor in
            if self.locationManager == nil {
                let lm = CLLocationManager()
                self.locationManager = lm
                if lm.authorizationStatus == .notDetermined {
                    lm.requestWhenInUseAuthorization()
                }
            }
        }
        
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isConnected = (path.status == .satisfied)
            
            var primaryBSD = "en0"
            for interface in path.availableInterfaces {
                if path.usesInterfaceType(interface.type) {
                    primaryBSD = interface.name
                    break
                }
            }
            
            self.primaryInterfaceBSD = primaryBSD
            let localIP = self.getIPAddress(for: primaryBSD) ?? "Unavailable"
            let gatewayIP: String
            if let firstGW = path.gateways.first {
                gatewayIP = "\(firstGW)"
            } else {
                gatewayIP = "None"
            }
            
            let wifiSSID = self.getWiFiSSID(for: primaryBSD)
            let displayName = wifiSSID ?? self.getDisplayName(for: primaryBSD)
            
            Task { @MainActor in
                NetworkStats.shared.isConnected = isConnected
                NetworkStats.shared.activeInterfaceBSD = primaryBSD
                NetworkStats.shared.activeInterfaceName = displayName
                NetworkStats.shared.activeWiFiSSID = wifiSSID
                NetworkStats.shared.localIP = localIP
                NetworkStats.shared.gatewayIP = gatewayIP
            }
            
            self.refreshInterfacesList()
        }
        
        pathMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Interface Discovery
    
    public func refreshInterfacesList() {
        var results: [InterfaceInfo] = []
        let scInterfaces = SCNetworkInterfaceCopyAll() as NSArray
        var nameMap: [String: String] = [:]
        
        for item in scInterfaces {
            let intf = item as! SCNetworkInterface
            if let bsd = SCNetworkInterfaceGetBSDName(intf) as String?,
               let name = SCNetworkInterfaceGetLocalizedDisplayName(intf) as String? {
                nameMap[bsd] = name
            }
        }
        
        // Query active interfaces via sysctl
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0
        if sysctl(&mib, 6, nil, &len, nil, 0) == 0 {
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
            defer { buf.deallocate() }
            
            if sysctl(&mib, 6, buf, &len, nil, 0) == 0 {
                var ptr = buf
                let end = buf.advanced(by: len)
                var seen = Set<String>()
                
                while ptr < end {
                    let msg = ptr.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }
                    if msg.ifm_type == RTM_IFINFO2 {
                        var nameBuf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                        if let cName = if_indextoname(UInt32(msg.ifm_index), &nameBuf) {
                            let bsd = String(cString: cName)
                            let flags = msg.ifm_flags
                            let isLoopback = (flags & IFF_LOOPBACK) != 0
                            let isUp = (flags & IFF_UP) != 0
                            
                            if !isLoopback && isUp && !seen.contains(bsd) {
                                seen.insert(bsd)
                                let disp = nameMap[bsd] ?? (bsd.hasPrefix("en") ? "Ethernet/Wi-Fi (\(bsd))" : bsd)
                                let isPrim = (bsd == self.primaryInterfaceBSD)
                                results.append(InterfaceInfo(bsdName: bsd, displayName: disp, isUp: isUp, isPrimary: isPrim))
                            }
                        }
                    }
                    ptr = ptr.advanced(by: Int(msg.ifm_msglen))
                }
            }
        }
        
        // Sort: primary first, then alphabetical
        results.sort {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            return $0.bsdName < $1.bsdName
        }
        
        Task { @MainActor in
            NetworkStats.shared.availableInterfaces = results
        }
    }
    
    private func getDisplayName(for bsdName: String) -> String {
        let scInterfaces = SCNetworkInterfaceCopyAll() as NSArray
        for item in scInterfaces {
            let intf = item as! SCNetworkInterface
            if let bsd = SCNetworkInterfaceGetBSDName(intf) as String?, bsd == bsdName,
               let name = SCNetworkInterfaceGetLocalizedDisplayName(intf) as String? {
                return name
            }
        }
        return bsdName.hasPrefix("en") ? "Wi-Fi" : bsdName
    }
    
    public func getWiFiSSID(for bsdName: String) -> String? {
        // 1. Try CoreWLAN first (native Apple framework)
        if let iface = CWWiFiClient.shared().interface(withName: bsdName) ?? CWWiFiClient.shared().interface() {
            if let ssid = iface.ssid(), !ssid.isEmpty, ssid != "<redacted>", !ssid.hasPrefix("<") {
                return ssid
            }
        }
        
        // 2. Try ipconfig
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ipconfig")
        task.arguments = ["getsummary", bsdName]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("SSID : ") {
                        let ssid = trimmed.replacingOccurrences(of: "SSID : ", with: "").trimmingCharacters(in: .whitespaces)
                        if !ssid.isEmpty && ssid != "<redacted>" && !ssid.hasPrefix("<") {
                            return ssid
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func getIPAddress(for bsdName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == bsdName && ptr.pointee.ifa_addr != nil {
                let family = ptr.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    return String(cString: hostname)
                }
            }
        }
        return nil
    }
    
    // MARK: - Sampling & Speed Measurement
    
    private func startSamplingTimer() {
        timer?.cancel()
        
        var interval: Double = 1.0
        var selectedSetting: String = "all"
        let currentPrimary = self.primaryInterfaceBSD
        
        var isEnabled = true
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                interval = AppSettings.shared.refreshInterval
                selectedSetting = AppSettings.shared.selectedInterface
                isEnabled = AppSettings.shared.isMonitoringEnabled
            }
        }
        
        guard isEnabled else { return }
        
        let newTimer = DispatchSource.makeTimerSource(queue: sampleQueue)
        newTimer.schedule(deadline: .now(), repeating: interval)
        newTimer.setEventHandler { [weak self] in
            self?.sampleNetworkSpeed(selectedMode: selectedSetting, primaryBSD: currentPrimary)
        }
        newTimer.resume()
        self.timer = newTimer
    }
    
    private func sampleNetworkSpeed(selectedMode: String, primaryBSD: String) {
        let (bytesIn, bytesOut) = getNetworkBytes(selectedMode: selectedMode, primaryBSD: primaryBSD)
        let now = CACurrentMediaTime()
        
        if isFirstSample || lastTime == 0 {
            lastBytesIn = bytesIn
            lastBytesOut = bytesOut
            lastTime = now
            isFirstSample = false
            return
        }
        
        let deltaTime = now - lastTime
        guard deltaTime > 0 else { return }
        
        // Guard against massive time jumps (e.g. macOS sleep/wake)
        if deltaTime > 10.0 {
            lastBytesIn = bytesIn
            lastBytesOut = bytesOut
            lastTime = now
            return
        }
        
        // Handle interface reconnection or counter wrap safely
        let deltaIn: UInt64
        if bytesIn >= lastBytesIn {
            deltaIn = bytesIn - lastBytesIn
        } else {
            deltaIn = 0
        }
        
        let deltaOut: UInt64
        if bytesOut >= lastBytesOut {
            deltaOut = bytesOut - lastBytesOut
        } else {
            deltaOut = 0
        }
        
        lastBytesIn = bytesIn
        lastBytesOut = bytesOut
        lastTime = now
        
        let downSpeed = Double(deltaIn) / deltaTime
        let upSpeed = Double(deltaOut) / deltaTime
        
        Task { @MainActor in
            NetworkStats.shared.updateSpeed(
                download: downSpeed,
                upload: upSpeed,
                deltaBytesIn: deltaIn,
                deltaBytesOut: deltaOut
            )
        }
    }
    
    private func getNetworkBytes(selectedMode: String, primaryBSD: String) -> (inBytes: UInt64, outBytes: UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else { return (0, 0) }
        
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { buf.deallocate() }
        
        guard sysctl(&mib, 6, buf, &len, nil, 0) == 0 else { return (0, 0) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = buf
        let end = buf.advanced(by: len)
        
        while ptr < end {
            let msg = ptr.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }
            if msg.ifm_type == RTM_IFINFO2 {
                let flags = msg.ifm_flags
                let isLoopback = (flags & IFF_LOOPBACK) != 0
                let isUp = (flags & IFF_UP) != 0
                
                if !isLoopback && isUp {
                    var nameBuf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if let cName = if_indextoname(UInt32(msg.ifm_index), &nameBuf) {
                        let bsd = String(cString: cName)
                        
                        let shouldCount: Bool
                        if selectedMode == "all" {
                            shouldCount = true
                        } else if selectedMode == "auto" {
                            shouldCount = (bsd == primaryBSD)
                        } else {
                            shouldCount = (bsd == selectedMode)
                        }
                        
                        if shouldCount {
                            totalIn += msg.ifm_data.ifi_ibytes
                            totalOut += msg.ifm_data.ifi_obytes
                        }
                    }
                }
            }
            ptr = ptr.advanced(by: Int(msg.ifm_msglen))
        }
        
        return (totalIn, totalOut)
    }
}
