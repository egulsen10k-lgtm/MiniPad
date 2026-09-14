//
//  VaultPinView.swift
//  MiniPad
//

import SwiftUI

struct VaultPinView: View {
    @ObservedObject var vaultManager: VaultManager
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color

    @State private var pin: String = ""
    @State private var shake: Bool = false

    private let digitCount = 4

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { vaultManager.cancelAuth() }

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(accentColor)
                        .padding(.top, 28)

                    Text(vaultManager.pendingAppPath != nil ? "Unlock to Launch" : "Vault PIN")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(textColor)

                    Text("Enter your 4-digit Vault PIN")
                        .font(.system(size: 11))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .padding(.bottom, 20)

                // PIN dots
                HStack(spacing: 14) {
                    ForEach(0..<digitCount, id: \.self) { i in
                        Circle()
                            .fill(i < pin.count ? accentColor : cardStrokeColor.opacity(0.5))
                            .frame(width: 13, height: 13)
                    }
                }
                .padding(.bottom, 28)
                .modifier(ShakeModifier(shake: shake))

                // Numpad
                VStack(spacing: 10) {
                    ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { n in
                                PinKey(label: "\(n)", accent: accentColor) { tap("\(n)") }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        PinKey(label: "✕", accent: .red.opacity(0.8)) { vaultManager.cancelAuth() }
                        PinKey(label: "0", accent: accentColor) { tap("0") }
                        PinKey(label: "⌫", accent: accentColor) { deleteLast() }
                    }
                }
                .padding(.bottom, 28)
            }
            .frame(width: 280)
            .background(cardFillColor.opacity(0.97), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(cardStrokeColor, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 28)
        }
    }

    private func tap(_ digit: String) {
        guard pin.count < digitCount else { return }
        pin += digit
        if pin.count == digitCount { submit() }
    }

    private func deleteLast() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    private func submit() {
        if vaultManager.verifyPIN(pin) {
            vaultManager.isUnlocked = true
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                vaultManager.isAuthenticating = false
            }
            vaultManager.onUnlock?()
            vaultManager.pendingAppPath = nil
            vaultManager.onUnlock = nil
        } else {
            pin = ""
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
        }
    }
}

private struct PinKey: View {
    let label: String
    let accent: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.85))
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

private struct ShakeModifier: ViewModifier {
    let shake: Bool
    func body(content: Content) -> some View {
        content.offset(x: shake ? 6 : 0)
            .animation(shake ? .default.repeatCount(5, autoreverses: true).speed(8) : .default, value: shake)
    }
}

// MARK: - Vault Locked App Row (Settings)
struct VaultLockedAppRow: View {
    let path: String
    let name: String
    @ObservedObject private var vault = VaultManager.shared

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 28, height: 28)
            Text(name).font(.subheadline)
            Spacer()
            Button {
                vault.unlock(path: path)
            } label: {
                Image(systemName: "lock.open.fill").foregroundStyle(.yellow)
            }
            .buttonStyle(.plain)
            .help("Remove from Vault")
        }
    }
}
