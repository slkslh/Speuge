import Foundation
import AppKit
import Darwin
import UniformTypeIdentifiers

public struct ResolvedAppInfo: Sendable {
    public let id: String
    public let displayName: String
    public let bundlePath: String?
    
    public init(id: String, displayName: String, bundlePath: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.bundlePath = bundlePath
    }
}

public final class AppInfoResolver: @unchecked Sendable {
    public static let shared = AppInfoResolver()
    
    private let queue = DispatchQueue(label: "com.networkspeed.appresolver", qos: .utility)
    private var cache: [String: ResolvedAppInfo] = [:]
    private var iconCache = NSCache<NSString, NSImage>()
    
    private init() {
        iconCache.countLimit = 250
    }
    
    /// Resolves raw process identifier string from nettop (e.g., "Google Chrome H.1962")
    public func resolve(procKey: String, pid: Int32?) -> ResolvedAppInfo {
        queue.sync {
            if let cached = cache[procKey] {
                return cached
            }
            
            let resolved = performResolve(procKey: procKey, pid: pid)
            cache[procKey] = resolved
            return resolved
        }
    }
    
    private func performResolve(procKey: String, pid: Int32?) -> ResolvedAppInfo {
        let actualPid: Int32? = pid ?? {
            let parts = procKey.split(separator: ".")
            if let last = parts.last, let p = Int32(last) {
                return p
            }
            return nil
        }()
        
        let rawBaseName: String = {
            let parts = procKey.split(separator: ".")
            if parts.count > 1, Int32(parts.last!) != nil {
                return parts.dropLast().joined(separator: ".")
            }
            return procKey
        }()
        
        // 1. Try NSRunningApplication if we have a valid PID
        if let p = actualPid, let app = NSRunningApplication(processIdentifier: pid_t(p)) {
            let bundleId = app.bundleIdentifier
            let name = app.localizedName ?? rawBaseName
            let bundlePath = app.bundleURL?.path
            
            // Clean up helper names if needed
            let cleanName = normalizeAppName(name)
            let finalId = bundleId ?? cleanName
            return ResolvedAppInfo(id: finalId, displayName: cleanName, bundlePath: bundlePath)
        }
        
        // 2. Query process path via Darwin proc_pidpath
        if let p = actualPid {
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let len = proc_pidpath(p, &pathBuffer, 4096)
            if len > 0 {
                let fullPath = String(cString: pathBuffer)
                
                // Check if process resides inside an .app bundle
                if let range = fullPath.range(of: ".app") {
                    let appBundlePath = String(fullPath[..<range.upperBound])
                    let bundle = Bundle(path: appBundlePath)
                    
                    let bundleName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                        ?? bundle?.infoDictionary?["CFBundleName"] as? String
                        ?? (appBundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                    
                    let cleanName = normalizeAppName(bundleName)
                    let bundleId = bundle?.bundleIdentifier ?? cleanName
                    
                    return ResolvedAppInfo(id: bundleId, displayName: cleanName, bundlePath: appBundlePath)
                } else {
                    // System binary or command line tool (e.g. /usr/bin/curl, /usr/sbin/mDNSResponder)
                    let binaryName = (fullPath as NSString).lastPathComponent
                    let cleanName = normalizeAppName(binaryName)
                    return ResolvedAppInfo(id: cleanName, displayName: cleanName, bundlePath: fullPath)
                }
            }
        }
        
        // 3. Fallback: normalize raw process name
        let cleanName = normalizeAppName(rawBaseName)
        return ResolvedAppInfo(id: cleanName, displayName: cleanName, bundlePath: nil)
    }
    
    /// Strips helper process suffixes and unifies apps
    private func normalizeAppName(_ name: String) -> String {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip common helper suffixes: " Google Chrome Helper (Renderer)" -> "Google Chrome"
        let helperPatterns = [
            " Helper (Renderer)",
            " Helper (GPU)",
            " Helper (Plugin)",
            " Helper (Alerts)",
            " Helper",
            "Helper",
            " H"
        ]
        
        for pat in helperPatterns {
            if clean.hasSuffix(pat) && clean.count > pat.count {
                clean = String(clean.dropLast(pat.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        // Special case mappings for common daemons
        let commonMap: [String: String] = [
            "mDNSResponder": "mDNSResponder (Bonjour)",
            "apsd": "Apple Push Notifications (apsd)",
            "airportd": "Wi-Fi Daemon (airportd)",
            "wifip2pd": "Wi-Fi Direct (wifip2pd)",
            "sharingd": "AirDrop & Sharing (sharingd)",
            "rapportd": "Apple Continuity (rapportd)",
            "identityservice": "iMessage & FaceTime (ids)",
            "cloudd": "iCloud Sync (cloudd)",
            "nsurlsessiond": "Background Downloads (nsurlsessiond)",
            "softwareupdated": "macOS Software Update"
        ]
        
        if let mapped = commonMap[clean] {
            return mapped
        }
        
        return clean.isEmpty ? "System Process" : clean
    }
    
    /// Resolves and caches the icon for an app display item
    public func icon(for id: String, bundlePath: String?, displayName: String) -> NSImage {
        let cacheKey = (id + (bundlePath ?? "")) as NSString
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }
        
        let loadedIcon: NSImage
        if let path = bundlePath, FileManager.default.fileExists(atPath: path) {
            loadedIcon = NSWorkspace.shared.icon(forFile: path)
        } else {
            // Choose a fitting SF Symbol based on name
            let lower = displayName.lowercased()
            let symbolName: String
            if lower.contains("safari") || lower.contains("chrome") || lower.contains("firefox") || lower.contains("browser") || lower.contains("http") || lower.contains("curl") {
                symbolName = "globe"
            } else if lower.contains("git") || lower.contains("terminal") || lower.contains("bash") || lower.contains("zsh") || lower.contains("node") || lower.contains("python") || lower.contains("swift") {
                symbolName = "terminal.fill"
            } else if lower.contains("wifi") || lower.contains("network") || lower.contains("mdns") || lower.contains("bluetooth") {
                symbolName = "network"
            } else if lower.contains("apple") || lower.contains("daemon") || lower.contains("system") || lower.contains("service") {
                symbolName = "gearshape.fill"
            } else {
                symbolName = "app.fill"
            }
            
            if let sysImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: displayName) {
                loadedIcon = sysImg
            } else {
                loadedIcon = NSWorkspace.shared.icon(for: .unixExecutable)
            }
        }
        
        iconCache.setObject(loadedIcon, forKey: cacheKey)
        return loadedIcon
    }
}
