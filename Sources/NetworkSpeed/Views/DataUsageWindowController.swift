import AppKit

@MainActor
public final class DataUsageWindowController {
    public static let shared = DataUsageWindowController()
    private init() {}
    
    public func show() {
        MainWindowController.shared.show(tab: .dataUsage)
    }
}
