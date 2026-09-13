//
//  NotchWindow.swift
//  MiniPad
//

import SwiftUI
import AppKit
import Combine

// MARK: - Safe Screen Positioning Helpers

struct ScreenGaps {
    let topGap: CGFloat
    let bottomGap: CGFloat
}

/// Calculate dynamic safe margins for the target screen to guarantee
/// that the launchpad and handle NEVER overlap the macOS menu bar or fall off the bottom.
func getScreenGaps() -> ScreenGaps {
    let screen = NotchWindow.getTargetScreen()
    let screenFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    
    // Top: distance from screen top to visible frame top (the menu bar height)
    let rawMenuBarHeight = max(screenFrame.maxY - visibleFrame.maxY, 0)
    // Guarantee at least 50pt margin (or actual menu bar + 16pt breathing room)
    // This strictly prevents ANY overlap with the macOS menu bar or camera notch.
    let topGap = max(rawMenuBarHeight + 16.0, 50.0)
    
    // Bottom: distance from screen bottom to visible frame bottom (Dock height)
    let rawDockHeight = max(visibleFrame.origin.y - screenFrame.origin.y, 0)
    // Guarantee at least 30pt bottom margin (or Dock height + 18pt breathing room)
    // This strictly keeps the launchpad from sticking to or falling off the bottom.
    let bottomGap = max(rawDockHeight + 18.0, 30.0)
    
    return ScreenGaps(topGap: topGap, bottomGap: bottomGap)
}

/// Convert handleVerticalPosition (0-600, 0=top) to a Y center in NSView coordinates
/// (0=bottom, canvasH=top). Strictly clamped so top of panel never enters menu bar,
/// and bottom of panel never touches the bottom screen margin.
func panelCentreY(canvasH: CGFloat, panelH: CGFloat, pos: Double) -> CGFloat {
    let gaps = getScreenGaps()
    let frac = CGFloat(min(max(pos, 30.0), 570.0)) / 600.0
    // Raw centre in NSView coords (0 = bottom, canvasH = top):
    let raw = canvasH * (1.0 - frac)
    
    // Minimum Y center: panel bottom (center - panelH/2) must stay >= bottomGap
    let lo = panelH / 2.0 + gaps.bottomGap
    // Maximum Y center: panel top (center + panelH/2) must stay <= canvasH - topGap
    let hi = canvasH - panelH / 2.0 - gaps.topGap
    
    if lo > hi {
        return (lo + hi) / 2.0
    }
    return min(max(raw, lo), hi)
}

/// SwiftUI offset from canvas center (positive = down, negative = up).
/// Exactly matches panelCentreY so AppKit hit testing and SwiftUI rendering are 100% in sync.
func panelSwiftUIOffset(canvasH: CGFloat, panelH: CGFloat, pos: Double) -> CGFloat {
    let cy = panelCentreY(canvasH: canvasH, panelH: panelH, pos: pos)
    return (canvasH / 2.0) - cy
}

// MARK: - NotchWindow

class NotchWindow: NSPanel {
    
    private var hostingView: PassThroughHostingView<NotchContentView>?
    private var cancellables = Set<AnyCancellable>()
    private var scrollMonitor: Any?
    private var lastScrollDate = Date()
    
    // Hover management state
    private var hoverTimer: Timer?
    private var handleHoverDwellCount: Int = 0
    private var outsideHoverCount: Int = 0
    
    var isExpanded: Bool { LaunchpadState.shared.isExpanded }
    
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
    
    init() {
        let screen = NotchWindow.getTargetScreen()
        let r = screen.frame
        super.init(
            contentRect: r,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setupWindow()
        setupObservers()
        setupScrollWheelMonitor()
        setupHoverMonitor()
    }
    
    static func getTargetScreen() -> NSScreen {
        let screens = NSScreen.screens
        let idx = AppSettings.shared.selectedScreenIndex
        if idx >= 0 && idx < screens.count { return screens[idx] }
        return NSScreen.main ?? screens.first ?? NSScreen()
    }
    
    // MARK: - Screen Frame Helpers for Exact Hitbox Tracking
    
    static func currentHandleScreenFrame() -> NSRect {
        let screen = getTargetScreen()
        let s = AppSettings.shared
        let isRight = s.handleEdge == .right
        let screenRect = screen.frame
        let canvasW = screenRect.width
        let canvasH = screenRect.height
        
        var hw: CGFloat
        var hh: CGFloat
        switch s.handleStyle {
        case .notch:  hw = 22; hh = 90
        case .mini:   hw = 12; hh = 65
        case .tab:    hw = 32; hh = 54
        case .custom: hw = CGFloat(s.handleWidth) + 6; hh = CGFloat(s.handleHeight) + 20
        default:      hw = 20; hh = 140
        }
        
        let cy = panelCentreY(canvasH: canvasH, panelH: hh, pos: s.handleVerticalPosition)
        let hx: CGFloat = isRight ? (canvasW - hw) : 0
        let hy = cy - hh / 2.0
        
        return NSRect(
            x: screenRect.origin.x + hx,
            y: screenRect.origin.y + hy,
            width: hw,
            height: hh
        )
    }
    
    static func currentLaunchpadScreenFrame() -> NSRect {
        let screen = getTargetScreen()
        let s = AppSettings.shared
        let isRight = s.handleEdge == .right
        let screenRect = screen.frame
        let canvasW = screenRect.width
        let canvasH = screenRect.height
        
        let lw = s.launchpadWidth + 8
        let lh = s.launchpadHeight + 8
        let cy = panelCentreY(canvasH: canvasH, panelH: lh, pos: s.handleVerticalPosition)
        let lx: CGFloat = isRight ? (canvasW - lw) : 0
        let ly = cy - lh / 2.0
        
        return NSRect(
            x: screenRect.origin.x + lx,
            y: screenRect.origin.y + ly,
            width: lw,
            height: lh
        )
    }
    
    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        acceptsMouseMovedEvents = true
        isMovableByWindowBackground = false
        
        let content = NotchContentView()
        let host = PassThroughHostingView(rootView: content)
        host.isExpanded = LaunchpadState.shared.isExpanded
        self.hostingView = host
        self.contentView = host
    }
    
    private func setupObservers() {
        LaunchpadState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                guard let self = self else { return }
                self.hostingView?.isExpanded = expanded
                if expanded {
                    self.makeKey()
                    self.orderFrontRegardless()
                } else {
                    self.resignKey()
                }
            }
            .store(in: &cancellables)
        
        AppSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.repositionWindow() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.repositionWindow() }
            .store(in: &cancellables)
    }
    
    // MARK: - Multi-Display Safe Hover Monitor
    
    private func setupHoverMonitor() {
        hoverTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkHoverState()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.hoverTimer = timer
    }
    
    private func checkHoverState() {
        let mouseLoc = NSEvent.mouseLocation
        let isExp = LaunchpadState.shared.isExpanded
        let isPinned = LaunchpadState.shared.isPinned
        let expandOnHover = AppSettings.shared.expandOnHover
        let isModalActive = AppDiscoveryManager.shared.isModalOrPopupActive
        
        guard expandOnHover && !isPinned else {
            handleHoverDwellCount = 0
            outsideHoverCount = 0
            return
        }
        
        if !isExp {
            // Collapsed: check if mouse is on the handle
            let handleFrame = NotchWindow.currentHandleScreenFrame()
            
            if handleFrame.contains(mouseLoc) {
                handleHoverDwellCount += 1
                // Require 4 consecutive ticks (200ms) of dwelling over handle.
                // Fast mouse sweeps across screen borders to another monitor pass in 10-30ms,
                // so they NEVER accidentally trigger expansion!
                if handleHoverDwellCount >= 4 {
                    handleHoverDwellCount = 0
                    DispatchQueue.main.async {
                        withAnimation(AppSettings.shared.animationStyle.spring) {
                            LaunchpadState.shared.setExpanded(true)
                        }
                    }
                }
            } else {
                handleHoverDwellCount = 0
            }
        } else {
            // Expanded: check if mouse is outside the launchpad
            guard !isModalActive else {
                outsideHoverCount = 0
                return
            }
            
            let launchpadFrame = NotchWindow.currentLaunchpadScreenFrame()
            // 14pt buffer around launchpad for smooth mouse movement
            let safeArea = launchpadFrame.insetBy(dx: -14, dy: -14)
            
            if safeArea.contains(mouseLoc) {
                outsideHoverCount = 0
            } else {
                outsideHoverCount += 1
                // 4 consecutive ticks (200ms) outside -> automatically close!
                // Works perfectly across all monitors and when clicking away!
                if outsideHoverCount >= 4 {
                    outsideHoverCount = 0
                    DispatchQueue.main.async {
                        withAnimation(AppSettings.shared.animationStyle.spring) {
                            LaunchpadState.shared.setExpanded(false)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Scroll Wheel & Category Scroll Interception
    
    private func setupScrollWheelMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  LaunchpadState.shared.isExpanded,
                  !AppDiscoveryManager.shared.isScrollLocked
            else { return event }
            
            let mouseLoc = NSEvent.mouseLocation
            let launchpadFrame = NotchWindow.currentLaunchpadScreenFrame()
            
            // 1. Check if user is scrolling over the Category Tabs Bar:
            // In Cocoa coordinates (Y from bottom), the Category Tabs Bar is 80pt to 145pt below top of launchpad.
            let categoryBarTop = launchpadFrame.maxY - 80
            let categoryBarBottom = launchpadFrame.maxY - 145
            let categoryBarFrame = NSRect(
                x: launchpadFrame.minX,
                y: categoryBarBottom,
                width: launchpadFrame.width,
                height: categoryBarTop - categoryBarBottom
            )
            
            if categoryBarFrame.contains(mouseLoc) {
                // Ignore scroll in category bar: let ScrollView handle interaction natively!
                return event
            }
            
            // 2. Otherwise: Regular App Grid Pagination (if enabled)
            guard AppSettings.shared.scrollPaginationEnabled else { return event }

            if launchpadFrame.contains(mouseLoc) {
                let dy = event.scrollingDeltaY
                let dx = event.scrollingDeltaX

                // Determine dominant scroll direction: vertical (dy) or horizontal (dx)
                let dominantDelta = abs(dy) >= abs(dx) ? dy : dx

                // Trackpad produces precise deltas; discrete mouse wheels produce non-precise deltas (e.g. ±1.0).
                let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 0.6 : 0.1

                if abs(dominantDelta) >= threshold {
                    let now = Date()
                    if now.timeIntervalSince(self.lastScrollDate) > 0.22 {
                        self.lastScrollDate = now
                        DispatchQueue.main.async {
                            withAnimation(AppSettings.shared.animationStyle.spring) {
                                if dominantDelta < 0 {
                                    AppDiscoveryManager.shared.nextPage()
                                } else {
                                    AppDiscoveryManager.shared.previousPage()
                                }
                            }
                        }
                    }
                }
            }
            return event
        }
    }
    
    /// Window always covers the target screen bounds.
    func repositionWindow() {
        let screen = NotchWindow.getTargetScreen()
        let r = screen.frame
        setFrame(r, display: true, animate: false)
    }
    
    func show() {
        repositionWindow()
        orderFrontRegardless()
    }
    
    deinit {
        hoverTimer?.invalidate()
        if let m = scrollMonitor { NSEvent.removeMonitor(m) }
    }
}

// MARK: - PassThroughHostingView

class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var isExpanded: Bool = false
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Multi-monitor safety check:
        // Strictly reject ANY point outside this window's bounds.
        // This prevents mouse coordinates near the edge of adjacent displays from triggering this view.
        guard bounds.contains(point) else { return nil }
        
        let s = AppSettings.shared
        let isRight = s.handleEdge == .right
        let canvasW = bounds.width
        let canvasH = bounds.height
        
        if isExpanded {
            // ── Expanded launchpad ─────────────────────────────────────────
            let lw = s.launchpadWidth + 8
            let lh = s.launchpadHeight + 8
            let cy = panelCentreY(canvasH: canvasH, panelH: lh, pos: s.handleVerticalPosition)
            let lx: CGFloat = isRight ? (canvasW - lw) : 0
            let ly = cy - lh / 2.0
            let r = NSRect(x: lx, y: ly, width: lw, height: lh)
            return r.contains(point) ? super.hitTest(point) : nil
            
        } else {
            // ── Idle handle ────────────────────────────────────────────────
            var hw: CGFloat
            var hh: CGFloat
            switch s.handleStyle {
            case .notch:  hw = 22; hh = 90
            case .mini:   hw = 12; hh = 65
            case .tab:    hw = 32; hh = 54
            case .custom: hw = CGFloat(s.handleWidth) + 6; hh = CGFloat(s.handleHeight) + 20
            default:      hw = 20; hh = 140
            }
            
            let cy = panelCentreY(canvasH: canvasH, panelH: hh, pos: s.handleVerticalPosition)
            let hx: CGFloat = isRight ? (canvasW - hw) : 0
            let hy = cy - hh / 2.0
            
            // STRICT HITBOX: Matches the visible handle area.
            // NEVER extends beyond the screen edge into adjacent monitors!
            let hitR = NSRect(x: hx, y: hy, width: hw, height: hh)
            return hitR.contains(point) ? super.hitTest(point) : nil
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Let setupScrollWheelMonitor handle window-level routing
        super.scrollWheel(with: event)
    }
}
