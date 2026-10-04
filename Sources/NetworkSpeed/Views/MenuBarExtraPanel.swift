import AppKit
import SwiftUI

@MainActor
public final class MenuBarExtraPanel: NSPanel {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var attachedButton: NSStatusBarButton?
    private var hostingView: NSHostingView<PopoverView>?
    public var onClose: (() -> Void)?
    
    private let panelWidth: CGFloat = 330
    private let panelHeight: CGFloat = 442
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovable = false
        self.hidesOnDeactivate = false
        
        setupContentView()
    }
    
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
    
    private func setupContentView() {
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16.0
        visualEffect.layer?.cornerCurve = .continuous
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
        visualEffect.autoresizingMask = [.width, .height]
        
        let hosting = NSHostingView(rootView: PopoverView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hosting
        
        visualEffect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
        ])
        
        self.contentView = visualEffect
    }
    
    public func show(attachedTo button: NSStatusBarButton) {
        self.attachedButton = button
        guard let window = button.window else { return }
        
        let buttonBounds = button.bounds
        let buttonScreenRect = window.convertToScreen(button.convert(buttonBounds, to: nil))
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        
        var panelX = buttonScreenRect.midX - (panelWidth / 2)
        let minX = screen.visibleFrame.minX + 8
        let maxX = screen.visibleFrame.maxX - panelWidth - 8
        panelX = min(max(panelX, minX), maxX)
        
        let panelY = buttonScreenRect.minY - panelHeight - 5
        
        self.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)
        
        startMonitoring()
        
        button.isHighlighted = true
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        self.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    public func closePanel() {
        stopMonitoring()
        
        attachedButton?.isHighlighted = false
        attachedButton = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.orderOut(nil)
                self.alphaValue = 1.0
                self.onClose?()
            }
        })
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        // Global monitor for clicks outside our app
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let clickLoc = NSEvent.mouseLocation
            
            // If the user clicked on the status item button, the button's action handles toggling.
            if let button = self.attachedButton, let btnWin = button.window {
                let btnScreenRect = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
                if btnScreenRect.contains(clickLoc) {
                    return
                }
            }
            
            if !self.frame.contains(clickLoc) {
                self.closePanel()
            }
        }
        
        // Local monitor for clicks inside our app but outside this panel
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            let clickLoc = NSEvent.mouseLocation
            
            if let button = self.attachedButton, let btnWin = button.window {
                let btnScreenRect = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
                if btnScreenRect.contains(clickLoc) {
                    return event
                }
            }
            
            if event.window != self && !self.frame.contains(clickLoc) {
                self.closePanel()
            }
            return event
        }
    }
    
    private func stopMonitoring() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }
    
    override public func cancelOperation(_ sender: Any?) {
        closePanel()
    }
    
    override public func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            closePanel()
        } else {
            super.keyDown(with: event)
        }
    }
}
