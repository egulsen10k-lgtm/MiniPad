//
//  SettingsView.swift
//  MiniPad
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var appManager = AppDiscoveryManager.shared
    @ObservedObject var iconManager = IconPackManager.shared
    var onClose: () -> Void = {}
    
    @StateObject private var vaultManager = VaultManager.shared
    @State private var newPinInput: String = ""
    @State private var confirmPinInput: String = ""
    @State private var vaultNotice: String = ""
    @State private var previewToggle: Bool = false
    @State private var selectedTab: SettingsTab = .appearance
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance & Themes"
        case behaviors = "Behaviors & Density"
        case displays = "Display & Screen"
        case vault = "Vault & Privacy"
        case about = "About MiniPad"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .appearance: return "paintpalette.fill"
            case .behaviors: return "slider.horizontal.3"
            case .displays: return "display.2"
            case .vault: return "lock.shield.fill"
            case .about: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .appearance: return .purple
            case .behaviors: return .orange
            case .displays: return .blue
            case .vault: return .yellow
            case .about: return .green
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (macOS Sonoma style)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("Settings")
                        .font(.headline)
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(tab.color)
                                    .frame(width: 22, height: 22)
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
                
                // Footer
                VStack(alignment: .leading, spacing: 4) {
                    Text("MiniPad v1.0")
                        .font(.caption2.bold())
                    Text("Native macOS Launchpad")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .frame(width: 210)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            
            Divider()
            
            // Detail / Content Area (Inset Card Group layout)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .appearance:
                            appearanceSettings
                        case .behaviors:
                            behaviorSettings
                        case .displays:
                            displaySettings
                        case .vault:
                            vaultSettings
                        case .about:
                            aboutSettings
                        }
                    }
                    .padding(24)
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("Done") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 720, height: 620)
    }
    
    @ViewBuilder
    private var vaultSettings: some View {
        SettingsCardView(title: "App Privacy Vault", icon: "lock.shield.fill") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Lock sensitive apps behind a PIN.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if vaultManager.hasPIN {
                    Label("PIN Set — Lock Enabled", systemImage: "lock.shield.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                } else {
                    Label("PIN Not Set — Configure Below", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Tab Contents
    
    @ViewBuilder
    private var appearanceSettings: some View {
        // --- ICON PACK SELECTOR ---
        SettingsCardView(title: "App Icon Style & Custom Icon Packs", icon: "app.dashed") {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(IconPackStyle.allCases) { style in
                        IconPackOptionCard(
                            style: style,
                            isSelected: settings.iconPackStyle == style,
                            onSelect: {
                                settings.iconPackStyle = style
                            }
                        )
                    }
                }
                
                Text(settings.iconPackStyle.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Custom Icon Pack Folder & Override Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Icon Pack Directory & Overrides")
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text("Active Directory: \(iconManager.customFolderURL.path)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            iconManager.chooseCustomPackFolder()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.gearshape")
                                Text("Choose Folder...")
                            }
                            .font(.caption)
                        }
                        
                        Button(action: {
                            iconManager.openCustomIconsFolderInFinder()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.forward.app")
                                Text("Open in Finder")
                            }
                            .font(.caption)
                        }
                        
                        Spacer()
                        
                        if !iconManager.customOverrides.isEmpty {
                            Button("Clear \(iconManager.customOverrides.count) Overrides") {
                                iconManager.clearAllCustomOverrides()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        
        // --- THEME SELECTOR ---
        SettingsCardView(title: "Visual Theme", icon: "paintpalette.fill") {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AppTheme.allCases) { th in
                        ThemeOptionCard(
                            theme: th,
                            isSelected: settings.theme == th,
                            onSelect: {
                                settings.theme = th
                            }
                        )
                    }
                }
                
                Text(settings.theme.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        // --- HANDLE STYLE CHOOSER ---
        SettingsCardView(title: "Edge Handle Style", icon: "rectangle.portrait.badge.plus") {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(HandleStyle.allCases) { style in
                        Button(action: { settings.handleStyle = style }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    // Miniature preview shape matching the actual handle design
                                    RoundedRectangle(cornerRadius: style == .notch ? 8 : (style == .tab ? 4 : 3))
                                        .fill(settings.handleStyle == style ? Color.accentColor : Color.secondary.opacity(0.25))
                                        .frame(
                                            width: style == .tab ? 30 : (style == .notch ? 18 : (style == .mini ? 6 : 12)),
                                            height: style == .tab ? 22 : (style == .notch ? 30 : 36)
                                        )
                                }
                                .frame(width: 50, height: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(settings.handleStyle == style ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                                
                                Text(style.rawValue)
                                    .font(.system(size: 10, weight: settings.handleStyle == style ? .bold : .medium))
                                    .foregroundColor(settings.handleStyle == style ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(settings.handleStyle.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        // --- ANIMATION STYLE CHOOSER ---
        SettingsCardView(title: "Animation & Motion Physics", icon: "waveform.path.ecg") {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AnimationStyle.allCases) { style in
                        AnimationOptionCard(
                            style: style,
                            isSelected: settings.animationStyle == style,
                            onSelect: {
                                settings.animationStyle = style
                                withAnimation(style.spring) {
                                    previewToggle.toggle()
                                }
                            }
                        )
                    }
                }
                
                // Interactive Spring Preview Box
                HStack {
                    Text("Interactive Physics Test:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(settings.animationStyle.spring) {
                            previewToggle.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Trigger Bounce")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                
                // Visual Bouncing Indicator
                HStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                        .offset(x: previewToggle ? 180 : 0)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                
                Divider()
                
                Toggle("Show App Names in Grid", isOn: $settings.showAppNames)
                    .font(.subheadline)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Seconds in Clock", isOn: $settings.showClockSeconds)
                        .font(.subheadline)
                    Text("⚠️ Warning: Updating every second may slightly increase CPU usage and power consumption.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Toggle("Show Welcome Animation & Greeting on Open", isOn: $settings.showWelcomeMessage)
                    .font(.subheadline)
                    
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Use Album Color Background for Spotify Widget", isOn: $settings.useAlbumColorWidget)
                        .font(.subheadline)
                    Text("Replaces the standard glass widget background with a vibrant gradient matched to the currently playing song's cover art.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var behaviorSettings: some View {
        // --- GRID DENSITY CUSTOMIZATION ---
        SettingsCardView(title: "Grid Density & Capacity", icon: "square.grid.3x2.fill") {
            VStack(spacing: 14) {
                HStack {
                    Text("Columns:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(settings.gridColumns)")
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.gridColumns) },
                        set: { settings.gridColumns = Int($0) }
                    ),
                    in: 3...8,
                    step: 1
                )
                
                HStack {
                    Text("Rows:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(settings.gridRows)")
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.gridRows) },
                        set: { settings.gridRows = Int($0) }
                    ),
                    in: 2...6,
                    step: 1
                )
                
                HStack {
                    Text("Apps Per Page:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(settings.itemsPerPage) items (Adaptive UI: \(Int(settings.launchpadWidth))×\(Int(settings.launchpadHeight)))")
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }
                
                Divider()
                
                Toggle("Trackpad / Scroll Wheel Page Pagination", isOn: $settings.scrollPaginationEnabled)
                    .font(.subheadline)
            }
        }
        
        // --- DRAWER & HANDLE DIMENSIONS ---
        SettingsCardView(title: "Custom Handle Dimensions & Opacity", icon: "slider.horizontal.3") {
            VStack(spacing: 14) {
                if settings.handleStyle == .custom {
                    HStack {
                        Text("Handle Width:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.handleWidth)) pt")
                            .font(.subheadline.bold())
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $settings.handleWidth, in: 8...36, step: 2)
                    
                    HStack {
                        Text("Handle Height:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.handleHeight)) pt")
                            .font(.subheadline.bold())
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $settings.handleHeight, in: 60...280, step: 10)
                } else {
                    Text("Select 'Custom Bar' edge handle style to fully customize length and thickness.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    Text("Background Opacity:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(settings.bgOpacity * 100))%")
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                }
                Slider(value: $settings.bgOpacity, in: 0.4...1.0, step: 0.05)
            }
        }
        
        // --- BEHAVIORS ---
        SettingsCardView(title: "Behaviors & Actions", icon: "gearshape.2.fill") {
            VStack(spacing: 12) {
                Toggle("Auto-expand drawer on hover", isOn: $settings.expandOnHover)
                    .font(.subheadline)
                
                Toggle("Auto-close launchpad when app launches", isOn: $settings.autoCloseOnLaunch)
                    .font(.subheadline)
                
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .font(.subheadline)
                
                HStack {
                    Text("App Sort Order:")
                        .font(.subheadline)
                    Spacer(minLength: 20)
                    Picker("", selection: $settings.sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                
                Divider()
                
                HStack {
                    Button("Refresh Installed Apps") {
                        appManager.refreshApps()
                    }
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("Reset All to Defaults") {
                        settings.resetToDefaults()
                    }
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    @ViewBuilder
    private var displaySettings: some View {
        // --- INTERACTIVE SCREEN & HANDLE POSITION MAP ---
        SettingsCardView(title: "Interactive Screen & Handle Position", icon: "macwindow") {
            VStack(spacing: 14) {
                Text("Drag the handle along the left edge to reposition its vertical placement on your screen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    // Monitor Screen Representation
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .frame(height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    
                    // Wallpaper gradient/texture inside screen
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.15), Color.blue.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4)
                    
                    // Simulated macOS Menu Bar at top of preview
                    VStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.primary.opacity(0.25)).frame(width: 3.5, height: 3.5)
                            RoundedRectangle(cornerRadius: 1).fill(Color.primary.opacity(0.15)).frame(width: 14, height: 2.5)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 11)
                        .background(Color.black.opacity(0.16))
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                        
                        Spacer()
                    }
                    
                    // Interactive Handle inside mini screen
                    GeometryReader { geo in
                        let previewH = geo.size.height
                        let previewW = geo.size.width
                        // Map handleVerticalPosition (0-600) to preview height
                        let frac = CGFloat(min(max(settings.handleVerticalPosition, 30), 570)) / 600.0
                        // Keep handle strictly below the simulated menu bar (minY: 22) and above bottom (maxY: previewH - 12)
                        let minY: CGFloat = 22
                        let maxY: CGFloat = previewH - 12
                        let handleY = minY + (maxY - minY) * frac
                        
                        let isRightEdge = settings.handleEdge == .right
                        
                        ZStack {
                            // Edge handle preview
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 36)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: isRightEdge ? -1 : 1, y: 0)
                            
                            // Grip lines
                            VStack(spacing: 2) {
                                ForEach(0..<3) { _ in
                                    Capsule().fill(Color.white).frame(width: 2, height: 4)
                                }
                            }
                        }
                        .position(x: isRightEdge ? previewW - 4 : 4, y: handleY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newFrac = min(max((value.location.y - minY) / (maxY - minY), 0.0), 1.0)
                                    settings.handleVerticalPosition = Double(newFrac) * 600.0
                                    
                                    // Snap to edge based on horizontal drag
                                    let newEdge: ScreenEdge = value.location.x > previewW / 2 ? .right : .left
                                    if settings.handleEdge != newEdge {
                                        settings.handleEdge = newEdge
                                    }
                                }
                        )
                    }
                    .padding(4)
                }
                .frame(height: 180)
                
                HStack {
                    Text("Side & Position:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(settings.handleEdge.rawValue) • \(Int(settings.handleVerticalPosition)) pt")
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }
            }
        }
        
        // --- DISPLAY & MONITOR SELECTION ---
        SettingsCardView(title: "Target Display (Multi-Screen)", icon: "display.2") {
            VStack(spacing: 10) {
                let screens = settings.getConnectedScreens()
                
                ForEach(screens, id: \.index) { sc in
                    let isSelected = settings.selectedScreenIndex == sc.index
                    Button(action: {
                        settings.selectedScreenIndex = sc.index
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: sc.isMain ? "display" : "display.trianglebadge.exclamationmark")
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(sc.name.isEmpty ? "Display \(sc.index + 1)" : sc.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if sc.isMain {
                                        Text("Main")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Text(sc.resolution)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private var aboutSettings: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            VStack(spacing: 16) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 4) {
                    Text("MiniPad")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Version 1.0")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Text("A lightweight, customizable launchpad experience for macOS.\nKeep your favourite apps accessible from the screen edge with beautiful themes, custom icon packs, and flexible layouts.")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .padding(.horizontal, 30)
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Developer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Emin Can")
                        .font(.caption.bold())
                }
                HStack {
                    Text("Platform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("macOS 13+")
                        .font(.caption.bold())
                }
                HStack {
                    Text("Built with")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("SwiftUI & AppKit")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 40)
            
            Spacer(minLength: 10)
            
            Text("© 2024 MiniPad. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
            
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable Settings Card
struct SettingsCardView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Icon Pack Option Card
struct IconPackOptionCard: View {
    let style: IconPackStyle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: style.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    Text(style.description)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animation Option Card
struct AnimationOptionCard: View {
    let style: AnimationStyle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: style.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 26)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    Text(style.description)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Option Card
struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Mini preview swatch
                ZStack {
                    switch theme {
                    case .liquidGlass:
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.22), Color(white: 0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                    case .frostedGlass:
                        RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                    case .opaque:
                        RoundedRectangle(cornerRadius: 6).fill(Color.black)
                    case .midnight:
                        RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.05, green: 0.1, blue: 0.25))
                    case .lightGlass:
                        RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.92))
                    }
                }
                .frame(width: 24, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                }
                
                Spacer(minLength: 0)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
