//
//  SettingsWindowManager.swift
//  MiniPad
//

import SwiftUI
import AppKit

class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()
    
    private var window: NSPanel?
    private var lastBeepTime: Date = Date.distantPast
    
    var isSettingsOpen: Bool {
        return window?.isVisible == true
    }
    
    func triggerWarningBeep() {
        let now = Date()
        if now.timeIntervalSince(lastBeepTime) > 1.2 {
            lastBeepTime = now
            NSSound.beep()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.window == nil {
                let settingsView = SettingsView(onClose: { [weak self] in
                    self?.closeSettings()
                })
                let hostingController = NSHostingController(rootView: settingsView)
                
                let panel = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 520, height: 740),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                panel.title = "MiniPad — Settings"
                panel.contentViewController = hostingController
                panel.isFloatingPanel = true
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.isReleasedWhenClosed = false
                panel.delegate = self
                panel.titlebarAppearsTransparent = false
                panel.backgroundColor = NSColor.windowBackgroundColor
                panel.center()
                self.window = panel
            }
            
            // Switch to regular so window is elevated to frontmost app level
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
            self.window?.center()
            self.window?.makeKeyAndOrderFront(nil)
            self.window?.orderFrontRegardless()
        }
    }
    
    func closeSettings() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
