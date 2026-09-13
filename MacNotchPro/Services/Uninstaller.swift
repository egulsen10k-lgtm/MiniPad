//
//  Uninstaller.swift
//  MiniPad
//

import AppKit
import Foundation

class Uninstaller {
    static let shared = Uninstaller()
    
    private let downloadURL = URL(string: "https://freemacsoft.net/appcleaner/")!
    
    func findAppCleanerURL() -> URL? {
        // 1. Check standard application directories
        let standardPaths = [
            "/Applications/AppCleaner.app",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/AppCleaner.app",
            "/Applications/Utilities/AppCleaner.app"
        ]
        for path in standardPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // 2. Check by bundle identifier
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.freemacsoft.AppCleaner") {
            return url
        }
        
        return nil
    }
    
    func uninstallApp(at path: String) {
        let appURL = URL(fileURLWithPath: path)
        let appName = appURL.deletingPathExtension().lastPathComponent
        
        if let appCleanerURL = findAppCleanerURL() {
            // AppCleaner is installed -> Open target app inside AppCleaner
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.open([appURL], withApplicationAt: appCleanerURL, configuration: config) { _, error in
                if let error = error {
                    print("Error opening AppCleaner: \(error.localizedDescription)")
                }
            }
        } else {
            // AppCleaner is NOT installed -> Prompt user & redirect to download website
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = NSAlert()
                alert.messageText = "AppCleaner Not Found"
                alert.informativeText = "MiniPad uses AppCleaner to completely delete '\(appName)' along with all its background extensions, caches, and leftover files.\n\nWould you like to download AppCleaner now?"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Download AppCleaner (Free)")
                alert.addButton(withTitle: "Move to Trash Only")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                let response = alert.runModal()
                
                if response == .alertFirstButtonReturn {
                    // Redirect to download page
                    NSWorkspace.shared.open(self.downloadURL)
                } else if response == .alertSecondButtonReturn {
                    // Fallback to simple trash
                    do {
                        try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
                        AppDiscoveryManager.shared.refreshApps()
                    } catch {
                        print("Failed to trash app: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
