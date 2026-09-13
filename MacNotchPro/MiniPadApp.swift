//
//  MiniPadApp.swift
//  MiniPad
//

import SwiftUI
import AppKit

@main
struct MiniPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindow: NotchWindow?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App starts in accessory mode (no Dock icon, status bar resident)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        
        DispatchQueue.main.async {
            self.notchWindow = NotchWindow()
            self.notchWindow?.show()
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.2.square", accessibilityDescription: "MiniPad")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Toggle Launchpad Drawer", action: #selector(toggleDrawer), keyEquivalent: "l")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(createFolderAction), keyEquivalent: "n")
        newFolderItem.target = self
        menu.addItem(newFolderItem)
        
        let refreshItem = NSMenuItem(title: "Refresh Installed Apps", action: #selector(rescanApps), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let restartItem = NSMenuItem(title: "Restart MiniPad", action: #selector(restartAppAction), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)
        
        let quitItem = NSMenuItem(title: "Quit MiniPad", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleDrawer() {
        LaunchpadState.shared.toggle()
    }
    
    @objc private func createFolderAction() {
        AppDiscoveryManager.shared.createNewEmptyFolder()
        LaunchpadState.shared.setExpanded(true)
    }
    
    @objc private func rescanApps() {
        AppDiscoveryManager.shared.refreshApps()
    }
    
    @objc private func openSettingsAction() {
        openSettings()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func restartAppAction() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["open", Bundle.main.bundlePath]
        
        // Fallback: spawn executable directly if bundle path is a swift build product
        let executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        
        DispatchQueue.global().async {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
                try process.run()
            } catch {
                // Fallback to launching via /usr/bin/open
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = [Bundle.main.bundlePath]
                try? openProcess.run()
            }
            
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
    
    @objc private func statusItemClicked() {
        // Handled by menu
    }
    
    private func openSettings() {
        SettingsWindowManager.shared.showSettings()
    }
}
