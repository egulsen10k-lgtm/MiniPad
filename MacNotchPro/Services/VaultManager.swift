//
//  VaultManager.swift
//  MiniPad
//

import SwiftUI
import AppKit
import Security
import Combine

class VaultManager: ObservableObject {
    static let shared = VaultManager()

    @Published var lockedAppPaths: Set<String> = []
    @Published var isUnlocked: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var pendingAppPath: String? = nil

    var onUnlock: (() -> Void)? = nil

    private let keychainService = "com.minipad.vault"
    private let keychainAccount = "vault-pin"
    private let lockedAppsKey = "vaultLockedApps"
    private var monitorTimer: Timer?

    init() {
        loadLockedApps()
        startMonitoring()
    }

    // MARK: - PIN

    var hasPIN: Bool { loadPIN() != nil }

    func setPIN(_ pin: String) { savePIN(pin) }

    func verifyPIN(_ pin: String) -> Bool {
        guard let stored = loadPIN() else { return false }
        return stored == pin
    }

    func removePIN() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        isUnlocked = false
    }

    private func savePIN(_ pin: String) {
        let data = pin.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let pin = String(data: data, encoding: .utf8) else { return nil }
        return pin
    }

    // MARK: - Locked Apps

    func lock(path: String) {
        lockedAppPaths.insert(path)
        saveLockedApps()
    }

    func unlock(path: String) {
        lockedAppPaths.remove(path)
        saveLockedApps()
    }

    func isLocked(_ path: String) -> Bool {
        lockedAppPaths.contains(path)
    }

    private func saveLockedApps() {
        UserDefaults.standard.set(Array(lockedAppPaths), forKey: lockedAppsKey)
    }

    private func loadLockedApps() {
        let arr = UserDefaults.standard.stringArray(forKey: lockedAppsKey) ?? []
        lockedAppPaths = Set(arr)
    }

    // MARK: - Auth Flow

    /// Call before launching a locked app. Shows PIN screen if needed.
    func requestUnlock(for path: String, then completion: @escaping () -> Void) {
        if isUnlocked {
            completion()
            return
        }
        
        // Kill any existing pending auth
        cancelAuthTimer()
        
        pendingAppPath = path
        onUnlock = completion
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isAuthenticating = true
        }
        
        // Start timeout to kill the app if user doesn't enter PIN
        startAuthTimeout()
    }
    
    private var authTimeoutTimer: Timer?
    private let authTimeoutSeconds: TimeInterval = 30 // 30 seconds to enter PIN
    
    private func startAuthTimeout() {
        cancelAuthTimer()
        authTimeoutTimer = Timer.scheduledTimer(withTimeInterval: authTimeoutSeconds, repeats: false) { [weak self] _ in
            self?.handleAuthTimeout()
        }
    }
    
    private func cancelAuthTimer() {
        authTimeoutTimer?.invalidate()
        authTimeoutTimer = nil
    }
    
    private func handleAuthTimeout() {
        // User didn't enter PIN in time - kill the pending app
        if let path = pendingAppPath {
            killApp(at: path)
        }
        cancelAuth()
    }
    
    private func killApp(at path: String) {
        for app in NSWorkspace.shared.runningApplications {
            guard let url = app.bundleURL else { continue }
            if url.path == path {
                app.forceTerminate()
            }
        }
    }

    func cancelAuth() {
        cancelAuthTimer()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isAuthenticating = false
        }
        pendingAppPath = nil
        onUnlock = nil
    }

    func lockVault() {
        cancelAuthTimer()
        isUnlocked = false
    }

    // MARK: - Background Monitor

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.killLockedRunningApps()
        }
    }

    private func killLockedRunningApps() {
        guard !isUnlocked, !lockedAppPaths.isEmpty else { return }
        for app in NSWorkspace.shared.runningApplications {
            guard let url = app.bundleURL else { continue }
            if lockedAppPaths.contains(url.path) {
                app.forceTerminate()
            }
        }
    }
}
