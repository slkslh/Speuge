import Foundation
import SwiftUI

public struct SpeedSample: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let download: Double
    public let upload: Double
    
    public init(timestamp: Date = Date(), download: Double, upload: Double) {
        self.timestamp = timestamp
        self.download = download
        self.upload = upload
    }
}

public struct InterfaceInfo: Identifiable, Hashable, Sendable {
    public var id: String { bsdName }
    public let bsdName: String
    public let displayName: String
    public let isUp: Bool
    public let isPrimary: Bool
    
    public init(bsdName: String, displayName: String, isUp: Bool, isPrimary: Bool = false) {
        self.bsdName = bsdName
        self.displayName = displayName
        self.isUp = isUp
        self.isPrimary = isPrimary
    }
}

@MainActor
public final class NetworkStats: ObservableObject {
    public static let shared = NetworkStats()
    
    @Published public var downloadSpeed: Double = 0
    @Published public var uploadSpeed: Double = 0
    
    @Published public var peakDownloadSpeed: Double = 0
    @Published public var peakUploadSpeed: Double = 0
    
    @Published public var sessionDownloadedBytes: UInt64 = 0
    @Published public var sessionUploadedBytes: UInt64 = 0
    
    @Published public var sessionStartTime: Date = Date()
    @Published public var isConnected: Bool = true
    
    @Published public var activeInterfaceBSD: String = "en0"
    @Published public var activeInterfaceName: String = "Wi-Fi"
    @Published public var activeWiFiSSID: String? = nil
    @Published public var localIP: String = "Detecting..."
    @Published public var gatewayIP: String = "..."
    
    @Published public var availableInterfaces: [InterfaceInfo] = []
    @Published public var history: [SpeedSample] = []
    
    private let maxHistoryLength = 60
    
    public init() {
        // Seed history with empty samples so sparkline renders smoothly from second zero
        let now = Date()
        history = (0..<maxHistoryLength).map { i in
            SpeedSample(timestamp: now.addingTimeInterval(Double(i - maxHistoryLength)), download: 0, upload: 0)
        }
    }
    
    public func updateSpeed(download: Double, upload: Double, deltaBytesIn: UInt64, deltaBytesOut: UInt64) {
        downloadSpeed = download
        uploadSpeed = upload
        
        if download > peakDownloadSpeed {
            peakDownloadSpeed = download
        }
        if upload > peakUploadSpeed {
            peakUploadSpeed = upload
        }
        
        sessionDownloadedBytes += deltaBytesIn
        sessionUploadedBytes += deltaBytesOut
        
        let sample = SpeedSample(timestamp: Date(), download: download, upload: upload)
        history.append(sample)
        if history.count > maxHistoryLength {
            history.removeFirst(history.count - maxHistoryLength)
        }
    }
    
    public func resetSession() {
        peakDownloadSpeed = 0
        peakUploadSpeed = 0
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
        sessionStartTime = Date()
        
        let now = Date()
        history = (0..<maxHistoryLength).map { i in
            SpeedSample(timestamp: now.addingTimeInterval(Double(i - maxHistoryLength)), download: 0, upload: 0)
        }
    }
}
