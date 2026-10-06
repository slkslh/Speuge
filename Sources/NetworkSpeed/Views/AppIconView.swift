import SwiftUI
import AppKit

/// Renders the official macOS application icon with Apple HIG squircle clipping,
/// subtle hairline border, and realistic drop shadow at any requested size.
public struct AppIconView: View {
    public let size: CGFloat
    public var showShadow: Bool
    
    public init(size: CGFloat = 36, showShadow: Bool = true) {
        self.size = size
        self.showShadow = showShadow
    }
    
    public var body: some View {
        Group {
            if let image = Self.loadAppIcon() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: squircleRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: squircleRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            } else {
                fallbackIcon
            }
        }
        .shadow(
            color: showShadow ? Color.black.opacity(0.18) : .clear,
            radius: max(1, size * 0.08),
            x: 0,
            y: max(0.5, size * 0.04)
        )
    }
    
    private var squircleRadius: CGFloat {
        // Apple HIG standard macOS app icon corner radius ratio (approx 22.4%)
        return size * 0.224
    }
    
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: squircleRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.indigo.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: squircleRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            
            Image(systemName: "gauge.with.needle.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Icon Loader
    
    private static var cachedIcon: NSImage? = nil
    
    private static func loadAppIcon() -> NSImage? {
        if let cached = cachedIcon {
            return cached
        }
        
        // 1. Try NSImage.applicationIconName
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            cachedIcon = icon
            return icon
        }
        
        // 2. Try AppIcon from main bundle resources
        if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconUrl), icon.isValid {
            cachedIcon = icon
            return icon
        }
        
        // 3. Try AppResources/AppIcon.icns in current working directory or relative path
        let candidates = [
            "AppResources/AppIcon.icns",
            "../AppResources/AppIcon.icns",
            "/Users/shalikfaris/Development/Network Sppeed/AppResources/AppIcon.icns"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path),
               let icon = NSImage(contentsOfFile: path), icon.isValid {
                cachedIcon = icon
                return icon
            }
        }
        
        // 4. Try NSApp.applicationIconImage
        if let icon = NSApp.applicationIconImage, icon.isValid {
            cachedIcon = icon
            return icon
        }
        
        return nil
    }
}
