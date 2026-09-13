//
//  LoginItemManager.swift
//  MiniPad
//

import Foundation
import ServiceManagement
import Combine

class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()
    
    @Published var isLaunchAtLoginEnabled: Bool = false {
        didSet {
            updateLoginItemStatus()
        }
    }
    
    init() {
        self.isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
    }
    
    private func updateLoginItemStatus() {
        do {
            if isLaunchAtLoginEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update login item status: \(error)")
        }
    }
}
