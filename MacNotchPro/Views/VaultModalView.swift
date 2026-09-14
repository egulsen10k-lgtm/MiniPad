//
//  VaultModalView.swift
//  MiniPad
//

import SwiftUI
import LocalAuthentication

struct VaultModalView: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var vaultManager: VaultManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onClose: () -> Void
    var onAppLaunched: () -> Void

    @State private var pin: String = ""
    @State private var shake: Bool = false
    @State private var isEditing: Bool = false
    @State private var draggedAppPath: String? = nil
    @State private var dropSideIsRight: Bool = false

    private let digitCount = 4

    private var lockedApps: [String] {
        Array(vaultManager.lockedAppPaths).sorted { path1, path2 in
            let name1 = (path1 as NSString).lastPathComponent.deletingPathExtension
            let name2 = (path2 as NSString).lastPathComponent.deletingPathExtension
            return name1.localizedStandardCompare(name2) == .orderedAscending
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("App Privacy Vault")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(textColor.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Divider().padding(.horizontal, 18).background(cardStrokeColor.opacity(0.3))

                // Content
                if !vaultManager.hasPIN {
                    // No PIN set - setup screen
                    VaultSetupView(
                        vaultManager: vaultManager,
                        textColor: textColor,
                        accentColor: accentColor,
                        cardFillColor: cardFillColor,
                        cardStrokeColor: cardStrokeColor
                    )
                } else if !vaultManager.isUnlocked {
                    // Locked - PIN entry
                    VaultUnlockView(
                        vaultManager: vaultManager,
                        textColor: textColor,
                        accentColor: accentColor,
                        cardFillColor: cardFillColor,
                        cardStrokeColor: cardStrokeColor,
                        onUnlock: { vaultManager.isUnlocked = true }
                    )
                } else {
                    // Unlocked - show vault contents
                    VaultContentsView(
                        appManager: appManager,
                        vaultManager: vaultManager,
                        textColor: textColor,
                        accentColor: accentColor,
                        cardFillColor: cardFillColor,
                        cardStrokeColor: cardStrokeColor,
                        onAppLaunched: onAppLaunched
                    )
                }
            }
            .frame(width: 420, height: 520)
            .background(cardFillColor.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(cardStrokeColor, lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 30)
        }
    }
}

// MARK: - Setup View (No PIN yet)
struct VaultSetupView: View {
    @ObservedObject var vaultManager: VaultManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var step: Int = 1 // 1 = enter, 2 = confirm
    @State private var shake: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(accentColor)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text(step == 1 ? "Set Vault PIN" : "Confirm PIN")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                Text("4+ digits. You'll need this to unlock the vault.")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            // PIN dots
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? accentColor : Color.primary.opacity(0.15))
                        .frame(width: 14, height: 14)
                }
            }
            .modifier(ShakeModifier(shake: shake))

            // Numpad
            VStack(spacing: 10) {
                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { n in
                            PinButton(label: "\(n)", accent: accentColor) { append("\(n)") }
                        }
                    }
                }
                HStack(spacing: 10) {
                    Spacer()
                    PinButton(label: "0", accent: accentColor) { append("0") }
                    Spacer()
                    PinButton(label: "⌫", accent: accentColor, isDelete: true) { deleteLast() }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 360)

        private func append(_ digit: String) {
            guard pin.count < 4 else { return }
            pin += digit
            if pin.count == 4 { handleComplete() }
        }

        private func deleteLast() { pin.removeLast() }

        private func handleComplete() {
            if step == 1 {
                step = 2
                pin = ""
            } else {
                if pin == confirmPin {
                    vaultManager.savePIN(pin)
                    vaultManager.isUnlocked = true
                } else {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = true }
                    pin = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
                }
            }
        }
    }
}

// MARK: - Unlock View (Has PIN, not unlocked)
struct VaultUnlockView: View {
    @ObservedObject var vaultManager: VaultManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    let onUnlock: () -> Void

    @State private var pin: String = ""
    @State private var shake: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(accentColor)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Unlock Vault")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                Text("Enter your 4-digit PIN to access locked apps.")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            // PIN dots
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? accentColor : Color.primary.opacity(0.15))
                        .frame(width: 14, height: 14)
                }
            }
            .modifier(ShakeModifier(shake: shake))

            // Numpad
            VStack(spacing: 10) {
                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { n in
                            PinButton(label: "\(n)", accent: accentColor) { append("\(n)") }
                        }
                    }
                }
                HStack(spacing: 10) {
                    PinButton(label: "✕", accent: .red.opacity(0.8)) { vaultManager.isUnlocked = false; pin = "" }
                    PinButton(label: "0", accent: accentColor) { append("0") }
                    PinButton(label: "⌫", accent: accentColor, isDelete: true) { deleteLast() }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 360)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isFocused = true } }

        private func append(_ digit: String) {
            guard pin.count < 4 else { return }
            pin += digit
            if pin.count == 4 { submit() }
        }

        private func deleteLast() { pin.removeLast() }

        private func submit() {
            if vaultManager.verifyPIN(pin) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    vaultManager.isUnlocked = true
                }
            } else {
                pin = ""
                withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = true }
            }
        }
    }
}

// MARK: - Contents View (Unlocked)
struct VaultContentsView: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var vaultManager: VaultManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onAppLaunched: () -> Void

    @State private var isEditing: Bool = false
    @State private var selectedApps: Set<String> = []
    @State private var draggedAppPath: String? = nil

    private var lockedApps: [String] {
        Array(vaultManager.lockedAppPaths).sorted { path1, path2 in
            let name1 = (path1 as NSString).lastPathComponent.deletingPathExtension
            let name2 = (path2 as NSString).lastPathComponent.deletingPathExtension
            return name1.localizedStandardCompare(name2) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(lockedApps.count) locked app\(lockedApps.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor.opacity(0.6))
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(appSettings.animationStyle.spring) { isEditing.toggle() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor)

                Button {
                    // Show change PIN dialog (requires macOS password)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Vault Settings")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 18)

            // Apps grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(lockedApps, id: \.self) { path in
                        let name = (path as NSString).lastPathComponent.deletingPathExtension
                        VaultAppCell(
                            path: path,
                            name: name,
                            isEditing: isEditing,
                            isSelected: selectedApps.contains(path),
                            textColor: textColor,
                            accentColor: accentColor,
                            cardFillColor: cardFillColor,
                            cardStrokeColor: cardStrokeColor,
                            onTap: { handleTap(path) },
                            onRemove: { removeFromVault(path) }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func handleTap(_ path: String) {
        if isEditing {
            withAnimation { selectedApps.symmetricDifference([path]) }
        } else {
            // Launch from vault - already unlocked so no PIN needed
            // This would need appManager.launchApp call
        }
    }

    private func removeFromVault(_ path: String) {
        withAnimation(appSettings.animationStyle.spring) {
            vaultManager.unlock(path: path)
            selectedApps.remove(path)
        }
    }
}

// MARK: - Pin Button
private struct PinButton: View {
    let label: String
    let accent: Color
    var isDelete: Bool = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.85))
                .frame(width: 64, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(pressed ? 0.18 : 0.07))
                )
                .scaleEffect(pressed ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { pressed = h } }
    }
}

// MARK: - Vault App Cell
private struct VaultAppCell: View {
    let path: String
    let name: String
    let isEditing: Bool
    let isSelected: Bool
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .cornerRadius(10)

                    if isEditing && isSelected {
                        Color.blue.opacity(0.3)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 48, height: 48)

                Text(name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 72)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? cardFillColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? accentColor : cardStrokeColor.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .contextMenu {
                Button("Remove from Vault") {
                    // Trigger remove via notification or closure
                }
            }
            .onHover { isHovered = $0 }
        }
    }
}

private struct ShakeModifier: ViewModifier {
    let shake: Bool
    func body(content: Content) -> some View {
        content.offset(x: shake ? 6 : 0)
            .animation(shake ? .default.repeatCount(5, autoreverses: true).speed(8) : .default, value: shake)
    }
}