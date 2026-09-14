//
//  NotchContentView.swift
//  MiniPad
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NotchContentView: View {
    @ObservedObject var launchpadState = LaunchpadState.shared
    @ObservedObject var appSettings = AppSettings.shared
    @ObservedObject var appManager = AppDiscoveryManager.shared
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        GeometryReader { geo in
            let isRight = appSettings.handleEdge == .right
            let ph: CGFloat = launchpadState.isExpanded ? appSettings.launchpadHeight : CGFloat(appSettings.handleHeight)
            // Use exact panelSwiftUIOffset shared with NotchWindow hit testing
            let vo = panelSwiftUIOffset(canvasH: geo.size.height, panelH: ph, pos: appSettings.handleVerticalPosition)
            
            ZStack(alignment: isRight ? .trailing : .leading) {
                if launchpadState.isExpanded {
                    ExpandedLaunchpadView(
                        appManager: appManager,
                        appSettings: appSettings,
                        launchpadState: launchpadState,
                        isSearchFocused: $isSearchFocused,
                        onOpenSettings: { SettingsWindowManager.shared.showSettings() },
                        onCollapse: { launchpadState.setExpanded(false) },
                        onAppLaunched: {
                            if appSettings.autoCloseOnLaunch && !launchpadState.isPinned {
                                launchpadState.setExpanded(false)
                            }
                        }
                    )
                    .frame(width: appSettings.launchpadWidth, height: appSettings.launchpadHeight)
                    .offset(y: vo)
                    .transition(.asymmetric(
                        insertion: .move(edge: isRight ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: isRight ? .trailing : .leading).combined(with: .opacity)
                    ))
                } else {
                    IdleHandleView(appSettings: appSettings)
                        .offset(y: vo)
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(appSettings.animationStyle.spring) {
                                launchpadState.setExpanded(true)
                            }
                        }
                }
            }
            .animation(appSettings.animationStyle.spring, value: launchpadState.isExpanded)
            .animation(appSettings.animationStyle.spring, value: appSettings.handleVerticalPosition)
            .animation(appSettings.animationStyle.spring, value: appSettings.gridColumns)
            .animation(appSettings.animationStyle.spring, value: appSettings.gridRows)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isRight ? .trailing : .leading)
            .contextMenu {
                Button(launchpadState.isExpanded ? "Collapse Launchpad" : "Open Launchpad") { launchpadState.toggle() }
                Divider()
                Button("Create New Folder") {
                    appManager.createNewEmptyFolder()
                    if !launchpadState.isExpanded { launchpadState.setExpanded(true) }
                }
                Button("Refresh Installed Apps") { appManager.refreshApps() }
                Button("Settings...") { SettingsWindowManager.shared.showSettings() }
                Divider()
                Button("Quit MiniPad") { NSApp.terminate(nil) }
            }
        }
    }
}
struct CustomRoundedShape: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        
        return path
    }
}

// MARK: - Idle Handle View
struct IdleHandleView: View {
    @ObservedObject var appSettings: AppSettings
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            let shape = shapeForStyle(appSettings.handleStyle)
            
            ThemeBackground(theme: appSettings.theme, opacity: appSettings.bgOpacity, shape: shape, isHovered: isHovering)
            
            // Visual Indicators based on style
            if appSettings.handleStyle == .pill {
                VStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Capsule().fill(Color.white.opacity(isHovering ? 0.9 : 0.4)).frame(width: 3, height: 10)
                    }
                }
            } else if appSettings.handleStyle == .notch {
                Circle()
                    .fill(Color.white.opacity(isHovering ? 0.8 : 0.3))
                    .frame(width: 6, height: 6)
            } else if appSettings.handleStyle == .tab {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(isHovering ? 1.0 : 0.6))
            }
        }
        .frame(
            width: widthForStyle(appSettings.handleStyle, isHovered: isHovering),
            height: heightForStyle(appSettings.handleStyle, isHovered: isHovering)
        )
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovering = h
            }
        }
        .gesture(
            DragGesture()
                .onChanged { _ in
                    // Use mouse coordinates relative to the target screen (multi-monitor safe)
                    let screen = NotchWindow.getTargetScreen()
                    let sr = screen.frame
                    let mouseY = NSEvent.mouseLocation.y - sr.origin.y   // 0 = screen bottom
                    let frac = 1.0 - (mouseY / sr.height)                 // 0 = top, 1 = bottom
                    let pos = frac * 600.0
                    appSettings.handleVerticalPosition = Double(min(max(pos, 30.0), 570.0))
                }
        )
    }

    private func shapeForStyle(_ style: HandleStyle) -> CustomRoundedShape {
        let isRight = appSettings.handleEdge == .right
        switch style {
        case .pill:
            return isRight
                ? CustomRoundedShape(topLeft: 10, bottomLeft: 10)
                : CustomRoundedShape(topRight: 10, bottomRight: 10)
        case .notch:
            return isRight
                ? CustomRoundedShape(topLeft: 24, bottomLeft: 24)
                : CustomRoundedShape(topRight: 24, bottomRight: 24)
        case .mini:
            return isRight
                ? CustomRoundedShape(topLeft: 4, bottomLeft: 4)
                : CustomRoundedShape(topRight: 4, bottomRight: 4)
        case .tab:
            return isRight
                ? CustomRoundedShape(topLeft: 8, bottomLeft: 8)
                : CustomRoundedShape(topRight: 8, bottomRight: 8)
        case .custom:
            return isRight
                ? CustomRoundedShape(topLeft: CGFloat(appSettings.handleCornerRadius), bottomLeft: CGFloat(appSettings.handleCornerRadius))
                : CustomRoundedShape(topRight: CGFloat(appSettings.handleCornerRadius), bottomRight: CGFloat(appSettings.handleCornerRadius))
        }
    }
    
    private func widthForStyle(_ style: HandleStyle, isHovered: Bool) -> CGFloat {
        switch style {
        case .pill: return isHovered ? 20 : 14
        case .notch: return isHovered ? 22 : 18
        case .mini: return 8
        case .tab: return 30
        case .custom: return CGFloat(appSettings.handleWidth) + (isHovered ? 6 : 0)
        }
    }
    
    private func heightForStyle(_ style: HandleStyle, isHovered: Bool) -> CGFloat {
        switch style {
        case .pill: return isHovered ? 140 : 120
        case .notch: return isHovered ? 100 : 80
        case .mini: return 60
        case .tab: return 50
        case .custom: return CGFloat(appSettings.handleHeight) + (isHovered ? 20 : 0)
        }
    }
}

// MARK: - Expanded Launchpad View
struct ExpandedLaunchpadView: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var launchpadState: LaunchpadState
    @ObservedObject var musicManager = MusicManager.shared
    @FocusState.Binding var isSearchFocused: Bool
    var onOpenSettings: () -> Void
    var onCollapse: () -> Void
    var onAppLaunched: () -> Void

    @State private var showDensityPopup: Bool = false
    // Static so it survives view recreation when collapsing/expanding
    private static var _welcomeDismissed: Bool = false
    @State private var showWelcomeBanner: Bool = false
    
    var body: some View {
        let sidebarShowing = launchpadState.isExpanded && appManager.selectedCategory == .all && appManager.searchText.isEmpty
        let sidebarPadding: CGFloat = sidebarShowing ? 12 : 16

        ZStack {
            let isRight = appSettings.handleEdge == .right
            let shape = isRight
                ? CustomRoundedShape(topLeft: 24, bottomLeft: 24)
                : CustomRoundedShape(topRight: 24, bottomRight: 24)
            ThemeBackground(theme: appSettings.theme, opacity: appSettings.bgOpacity, shape: shape, isHovered: false)
                .shadow(color: Color.black.opacity(0.55), radius: 24, x: isRight ? -8 : 8, y: 0)

            // Main content area with widgets at the bottom
            VStack(spacing: 8) {
                // Header Bar
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                        
                        Text("MiniPad")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        
                        if appManager.isEditing {
                            // Editing mode: show selection count + Done button
                            Text("\(appManager.selectedItems.count) Selected")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                )
                            
                            Button("Done") {
                                withAnimation(appSettings.animationStyle.spring) {
                                    appManager.exitEditingMode()
                                }
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                            .buttonStyle(.plain)
                        } else {
                            Text("\(appManager.filteredItems.count) Items")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.65))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(cardFillColor)
                                        .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                                )
                        }
                        
                        // Clickable Apps Displayed Per Page Badge / Density Trigger (compact)
                        Button(action: {
                            withAnimation(appSettings.animationStyle.spring) {
                                showDensityPopup.toggle()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "square.grid.3x2")
                                    .font(.system(size: 8, weight: .semibold))
                                Text("\(appSettings.gridColumns)×\(appSettings.gridRows)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(showDensityPopup ? (appSettings.theme == .lightGlass ? Color(white: 0.10) : Color.white) : textColor.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(showDensityPopup ? accentColor.opacity(0.85) : cardFillColor)
                                    .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Customize Grid Density & Animation Physics")
                    }
                    
                    Spacer()
                    
                    // Little HH:MM digital clock - perfectly centered
                    DigitalClockView(textColor: textColor.opacity(0.8))
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Sort Mode Toggle Button (compact)
                        Button(action: {
                            withAnimation(appSettings.animationStyle.spring) {
                                appSettings.sortMode = (appSettings.sortMode == .alphabetical) ? .custom : .alphabetical
                            }
                        }) {
                            Image(systemName: appSettings.sortMode == .alphabetical ? "textformat" : "hand.draw")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.85))
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(cardFillColor)
                                        .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Toggle App Order (Alphabetical vs Custom)")
                    
                    Spacer()
                    
                    // New Folder Button (or Group Selected when in editing mode)
                    Button(action: {
                        withAnimation(appSettings.animationStyle.spring) {
                            if appManager.isEditing {
                                // Group selected items into folder
                                appManager.createFolderFromSelectedItems()
                            } else {
                                appManager.createNewEmptyFolder()
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: appManager.isEditing ? "folder.badge.plus" : "folder.badge.plus")
                                .font(.system(size: 11))
                            Text(appManager.isEditing ? "Group Items" : "New Folder")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundColor(textColor.opacity(appSettings.theme == .lightGlass ? 1.0 : 0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            Capsule()
                                .fill(cardFillColor)
                                .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Pin Button
                    Button(action: {
                        withAnimation(appSettings.animationStyle.spring) {
                            launchpadState.isPinned.toggle()
                        }
                    }) {
                        Image(systemName: launchpadState.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(launchpadState.isPinned ? accentColor : textColor.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(cardFillColor)
                                    .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.6))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(launchpadState.isPinned ? "Unpin Drawer" : "Keep Open")
                    
                    // Settings Button - Direct Reliable Trigger
                    Button(action: {
                        SettingsWindowManager.shared.showSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textColor.opacity(appSettings.theme == .lightGlass ? 1.0 : 0.85))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(cardFillColor)
                                    .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.6))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings")

                    // Collapse Button
                    Button(action: onCollapse) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(textColor.opacity(0.65))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(cardFillColor)
                                    .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.6))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Collapse")
                    }
                }
                .padding(.horizontal, sidebarPadding)
                .padding(.top, 12)
                
                // Welcoming Animation & Greeting Banner
                if showWelcomeBanner && appSettings.showWelcomeMessage {
                    WelcomingBannerView(
                        textColor: textColor,
                        accentColor: accentColor,
                        cardFillColor: cardFillColor,
                        cardStrokeColor: cardStrokeColor,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showWelcomeBanner = false
                                ExpandedLaunchpadView._welcomeDismissed = true
                            }
                        }
                    )
                    .padding(.horizontal, sidebarPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Embedded Recessed Search Bar Well
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.55))
                    
                    TextField("Search applications & folders...", text: $appManager.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(textColor)
                        .focused($isSearchFocused)
                    
                    if !appManager.searchText.isEmpty {
                        Button(action: {
                            withAnimation(appSettings.animationStyle.spring) {
                                appManager.searchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(textColor.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(appSettings.theme == .liquidGlass ? Color.black.opacity(0.26) : cardFillColor)
                        
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 0.7)
                    }
                )
                .padding(.horizontal, sidebarPadding)

                // Category Tabs Bar
                CategoryTabsBarView(
                    appManager: appManager,
                    appSettings: appSettings,
                    textColor: textColor,
                    accentColor: accentColor,
                    cardFillColor: cardFillColor,
                    cardStrokeColor: cardStrokeColor
                )
                .padding(.horizontal, 16)
                
                // Adaptive Grid of Apps / Folders
                let currentItems = appManager.itemsForCurrentPage()
                
                if appManager.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                    Text("Scanning applications...")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.5))
                    Spacer()
                } else if currentItems.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: appManager.selectedCategory.icon)
                            .font(.system(size: 26))
                            .foregroundColor(textColor.opacity(0.3))
                        Text(appManager.searchText.isEmpty ? "No \(appManager.selectedCategory.rawValue) items found" : "No matching items found for \"\(appManager.searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    Spacer()
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: appSettings.gridColumns),
                        spacing: 4
                    ) {
                        ForEach(currentItems) { item in
                            LaunchpadItemCellView(
                                item: item,
                                appManager: appManager,
                                appSettings: appSettings,
                                textColor: textColor,
                                cardFillColor: cardFillColor,
                                cardStrokeColor: cardStrokeColor,
                                onAppClick: { path in
                                    appManager.launchApp(at: path) {
                                        onAppLaunched()
                                    }
                                }
                            )
                        }
                    }
                    .id("grid-page-\(appManager.currentPage)-\(appManager.selectedCategory.rawValue)-\(appSettings.iconPackStyle.rawValue)")
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 15)
                            .onEnded { value in
                                let hTrans = value.translation.width
                                let vTrans = value.translation.height
                                // Only trigger pagination for horizontal swipes (or when horizontal movement dominates)
                                if abs(hTrans) > abs(vTrans) {
                                    if hTrans < -25 {
                                        withAnimation(appSettings.animationStyle.spring) {
                                            appManager.nextPage()
                                        }
                                    } else if hTrans > 25 {
                                        withAnimation(appSettings.animationStyle.spring) {
                                            appManager.previousPage()
                                        }
                                    }
                                }
                            }
                    )
                }
                
                // Bottom Pagination Bar
                if !appManager.isLoading && appManager.totalPages > 1 {
                    HStack(spacing: 14) {
                        // Previous Page Button
                        Button(action: {
                            withAnimation(appSettings.animationStyle.spring) {
                                appManager.previousPage()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(appManager.currentPage > 0 ? textColor : textColor.opacity(appSettings.theme == .lightGlass ? 0.25 : 0.2))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(cardFillColor)
                                        .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(appManager.currentPage == 0)
                        .contentShape(Circle())

                        // Page Indicators
                        HStack(spacing: 5) {
                            ForEach(0..<min(appManager.totalPages, 14), id: \.self) { index in
                                PageIndicatorDotView(
                                    index: index,
                                    currentPage: appManager.currentPage,
                                    accentColor: accentColor,
                                    textColor: textColor,
                                    animationStyle: appSettings.animationStyle.spring,
                                    onSelect: {
                                        withAnimation(appSettings.animationStyle.spring) {
                                            appManager.currentPage = index
                                        }
                                    }
                                )
                            }
                        }

                        // Next Page Button
                        Button(action: {
                            withAnimation(appSettings.animationStyle.spring) {
                                appManager.nextPage()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(appManager.currentPage < appManager.totalPages - 1 ? textColor : textColor.opacity(appSettings.theme == .lightGlass ? 0.25 : 0.2))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(cardFillColor)
                                        .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(appManager.currentPage >= appManager.totalPages - 1)
                        .contentShape(Circle())
                    }
                    .padding(.bottom, 4)
                }

                // Mini Spotify Bar at the very bottom
                MiniSpotifyBottomBar(
                    musicManager: musicManager,
                    textColor: textColor,
                    accentColor: accentColor,
                    cardFillColor: cardFillColor,
                    cardStrokeColor: cardStrokeColor
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Grid Density & Animation Style Popup Modal
            if showDensityPopup {
                GridDensityModalView(
                    appSettings: appSettings,
                    textColor: textColor,
                    accentColor: accentColor,
                    cardFillColor: cardFillColor,
                    cardStrokeColor: cardStrokeColor,
                    onOpenSettings: {
                        showDensityPopup = false
                        SettingsWindowManager.shared.showSettings()
                    },
                    onClose: {
                        withAnimation(appSettings.animationStyle.spring) {
                            showDensityPopup = false
                        }
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            
            // Folder Modal Popover
            if let activeFolder = appManager.activeFolder {
                FolderModalView(
                    folder: activeFolder,
                    appManager: appManager,
                    appSettings: appSettings,
                    textColor: textColor,
                    accentColor: accentColor,
                    cardFillColor: cardFillColor,
                    cardStrokeColor: cardStrokeColor,
                    onClose: {
                        withAnimation(appSettings.animationStyle.spring) {
                            appManager.activeFolder = nil
                        }
                    },
                    onAppLaunched: onAppLaunched
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

        }
        .frame(width: appSettings.launchpadWidth, height: appSettings.launchpadHeight)

        .onAppear {
            if launchpadState.isExpanded && appSettings.showWelcomeMessage && !ExpandedLaunchpadView._welcomeDismissed {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showWelcomeBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showWelcomeBanner = false
                        ExpandedLaunchpadView._welcomeDismissed = true
                    }
                }
            }
        }
        .onChange(of: launchpadState.isExpanded) { expanded in
            if expanded && appSettings.showWelcomeMessage && !ExpandedLaunchpadView._welcomeDismissed {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showWelcomeBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showWelcomeBanner = false
                        ExpandedLaunchpadView._welcomeDismissed = true // Prevent showing again for this session
                    }
                }
            }
        }
        .onChange(of: showDensityPopup) { isOpen in
            appManager.isModalOrPopupActive = isOpen
        }
        .onDisappear {
            showDensityPopup = false
            appManager.isModalOrPopupActive = false
        }
    }

    private var textColor: Color {
        appSettings.theme == .lightGlass ? Color(white: 0.10) : Color.white
    }

    private var accentColor: Color {
        switch appSettings.theme {
        case .midnight:
            return Color.cyan
        case .liquidGlass:
            return Color.white.opacity(0.95)
        case .lightGlass:
            return Color(red: 0.0, green: 0.42, blue: 0.85)
        default:
            return Color.accentColor
        }
    }

    private var cardFillColor: Color {
        switch appSettings.theme {
        case .lightGlass:
            return Color.black.opacity(0.09)
        case .liquidGlass:
            return Color.white.opacity(0.09)
        default:
            return Color.white.opacity(0.08)
        }
    }

    private var cardStrokeColor: Color {
        switch appSettings.theme {
        case .lightGlass:
            return Color.black.opacity(0.16)
        case .liquidGlass:
            return Color.white.opacity(0.18)
        default:
            return Color.white.opacity(0.12)
        }
    }
}

// MARK: - Add Apps Modal
struct AddAppsModalView: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onClose: () -> Void
    
    @State private var searchText: String = ""
    @State private var selectedPaths: Set<String> = []
    
    // Apps that exist on disk but are NOT in the current launchpad items
    private var availableApps: [(name: String, path: String, icon: NSImage)] {
        let existingPaths = Set(appManager.items.compactMap { item -> [String]? in
            if item.isFolder {
                return item.subAppPaths
            } else {
                return item.path.map { [$0] }
            }
        }.flatMap { $0 })
        
        var apps: [(name: String, path: String, icon: NSImage)] = []
        for (path, meta) in appManager.allAppsCache {
            if !existingPaths.contains(path) {
                apps.append((name: meta.name, path: path, icon: meta.icon))
            }
        }
        
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "plus.app.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                
                Text("Add Apps")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                
                Text("\(availableApps.count) available")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.5))
                
                Spacer()
                
                if !selectedPaths.isEmpty {
                    Text("\(selectedPaths.count) selected")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(textColor.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textColor.opacity(0.4))
                
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(textColor.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 0.6)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // App List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableApps, id: \.path) { app in
                        let isSelected = selectedPaths.contains(app.path)
                        
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                            
                            Text(app.name)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? accentColor : textColor.opacity(0.25))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                if isSelected {
                                    selectedPaths.remove(app.path)
                                } else {
                                    selectedPaths.insert(app.path)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Footer
            HStack(spacing: 10) {
                // Select All / Deselect All
                Button(action: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        if selectedPaths.count == availableApps.count {
                            selectedPaths.removeAll()
                        } else {
                            selectedPaths = Set(availableApps.map { $0.path })
                        }
                    }
                }) {
                    Text(selectedPaths.count == availableApps.count ? "Deselect All" : "Select All")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(cardFillColor)
                                .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Add Selected Button
                Button(action: {
                    for path in selectedPaths {
                        let name = appManager.allAppsCache[path]?.name ?? (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "App"
                        let newItem = LaunchpadItem(
                            id: path,
                            name: name,
                            type: .app,
                            path: path,
                            subAppPaths: nil
                        )
                        appManager.items.append(newItem)
                    }
                    appManager.filterItems()
                    appManager.saveLayout()
                    selectedPaths.removeAll()
                    onClose()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add \(selectedPaths.count) App\(selectedPaths.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(selectedPaths.isEmpty ? Color.gray.opacity(0.4) : accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedPaths.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    appSettings.theme == .lightGlass
                        ? Color.white.opacity(0.92)
                        : Color.black.opacity(0.85)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20)
        )
        .padding(12)
    }
}

// MARK: - Grid Density & Animation Style Modal Popover
struct GridDensityModalView: View {
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onOpenSettings: () -> Void
    var onClose: () -> Void
    
    let presets: [(cols: Int, rows: Int, label: String)] = [
        (4, 2, "4×2 (8)"),
        (4, 3, "4×3 (12)"),
        (5, 3, "5×3 (15)"),
        (6, 3, "6×3 (18)"),
        (6, 4, "6×4 (24)"),
        (7, 4, "7×4 (28)")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 14) {
                // Modal Header
                HStack {
                    Image(systemName: "square.grid.3x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                    
                    Text("Grid Density & Animation")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(textColor.opacity(0.12))
                
                // Section 1: Quick Density Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Presets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(presets, id: \.label) { p in
                            let isSelected = appSettings.gridColumns == p.cols && appSettings.gridRows == p.rows
                            Button(action: {
                                withAnimation(appSettings.animationStyle.spring) {
                                    appSettings.gridColumns = p.cols
                                    appSettings.gridRows = p.rows
                                }
                            }) {
                                Text(p.label)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                                    .foregroundColor(isSelected ? (appSettings.theme == .liquidGlass ? Color.black : (textColor == .black ? Color.black : Color.white)) : textColor.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? (appSettings.theme == .liquidGlass ? Color.white.opacity(0.92) : accentColor) : cardFillColor)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.clear : cardStrokeColor, lineWidth: 0.6))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Section 2: Sliders
                VStack(spacing: 8) {
                    HStack {
                        Text("Columns: \(appSettings.gridColumns)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textColor.opacity(0.85))
                            .frame(width: 80, alignment: .leading)
                        
                        Slider(
                            value: Binding(
                                get: { Double(appSettings.gridColumns) },
                                set: { appSettings.gridColumns = Int($0) }
                            ),
                            in: 3...8,
                            step: 1
                        )
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("Rows: \(appSettings.gridRows)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textColor.opacity(0.85))
                            .frame(width: 80, alignment: .leading)
                        
                        Slider(
                            value: Binding(
                                get: { Double(appSettings.gridRows) },
                                set: { appSettings.gridRows = Int($0) }
                            ),
                            in: 2...6,
                            step: 1
                        )
                        .labelsHidden()
                    }
                    
                    Text("\(appSettings.gridColumns) cols × \(appSettings.gridRows) rows = **\(appSettings.itemsPerPage) apps per page** (Adaptive UI: \(Int(appSettings.launchpadWidth))×\(Int(appSettings.launchpadHeight)))")
                        .font(.system(size: 9.5))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cardFillColor)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardStrokeColor, lineWidth: 0.6))
                )
                
                // Section 3: Animation Physics Chooser
                VStack(alignment: .leading, spacing: 6) {
                    Text("Animation Style")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(AnimationStyle.allCases) { style in
                            let isSelected = appSettings.animationStyle == style
                            Button(action: {
                                withAnimation(style.spring) {
                                    appSettings.animationStyle = style
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(style.rawValue)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        Text(style.description)
                                            .font(.system(size: 8.5))
                                            .foregroundColor(isSelected ? (appSettings.theme == .liquidGlass ? Color.black.opacity(0.7) : (textColor == .black ? Color.black.opacity(0.7) : Color.white.opacity(0.85))) : textColor.opacity(0.45))
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer(minLength: 0)
                                }
                                .foregroundColor(isSelected ? (appSettings.theme == .liquidGlass ? Color.black : (textColor == .black ? Color.black : Color.white)) : textColor.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? (appSettings.theme == .liquidGlass ? Color.white.opacity(0.92) : accentColor) : cardFillColor)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.clear : cardStrokeColor, lineWidth: 0.6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                    .background(textColor.opacity(0.12))
                
                // Footer
                HStack {
                    Button("More Settings...") {
                        SettingsWindowManager.shared.showSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.65))
                    
                    Spacer()
                    
                    Button("Done") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.10).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 24, y: 10)
            )
        }
    }
}

// MARK: - Category Tabs Bar View
struct CategoryTabsBarView: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AppCategory.allCases) { cat in
                        let isSelected = appManager.selectedCategory == cat
                        let count = appManager.count(for: cat)
                        
                        if count > 0 || cat == .all || cat == .folders {
                            Button(action: {
                                withAnimation(appSettings.animationStyle.spring) {
                                    appManager.selectedCategory = cat
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    
                                    Text(cat.rawValue)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1.5)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? (appSettings.theme == .liquidGlass ? Color.black.opacity(0.2) : Color.white.opacity(0.25)) : Color.white.opacity(0.08))
                                            )
                                    }
                                }
                                .foregroundColor(isSelected ? (appSettings.theme == .liquidGlass ? Color.black : (textColor == .black ? Color.black : Color.white)) : textColor.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            Capsule()
                                                .fill(
                                                    appSettings.theme == .liquidGlass
                                                        ? LinearGradient(
                                                            colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                        : LinearGradient(colors: [accentColor.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 0.8))
                                                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)
                                        } else {
                                            Capsule()
                                                .fill(cardFillColor)
                                                .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .id(cat)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .onChange(of: appManager.selectedCategory) { newCat in
                withAnimation { proxy.scrollTo(newCat, anchor: .center) }
            }
        }
        .frame(height: 38)
    }
}

// MARK: - Launchpad Item Cell (App or Folder)
struct LaunchpadItemCellView: View {
    let item: LaunchpadItem
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    let onAppClick: (String) -> Void
    
    @State private var isHovered = false
    @State private var isTargetedForDrop = false
    @State private var dwellProgress: CGFloat = 0.0
    @State private var dwellTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if item.isFolder {
                    // Folder Preview
                    ZStack(alignment: .topTrailing) {
                        FolderIconPreviewView(
                            subPaths: item.subAppPaths ?? [],
                            appManager: appManager,
                            appSettings: appSettings,
                            size: appSettings.iconSize
                        )
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(appSettings.animationStyle.spring, value: isHovered)
                        
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                                .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                                .offset(x: 4, y: -4)
                        }
                    }
                } else if let path = item.path {
                    // Standard App Icon (Supports Native, Dark, Light, Liquid Glass & Custom Overrides)
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: appManager.icon(for: path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: appSettings.iconSize, height: appSettings.iconSize)
                            .shadow(color: Color.black.opacity(isHovered ? 0.45 : 0.2), radius: isHovered ? 5 : 2, y: isHovered ? 2 : 1)
                            .scaleEffect(isHovered ? (appSettings.enableDockHoverEffect ? 1.25 : 1.06) : 1.0)
                            .animation(appSettings.animationStyle.spring, value: isHovered)
                        
                        if IconPackManager.shared.hasCustomIcon(for: path) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .offset(x: 2, y: -2)
                        }
                        
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                                .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                
                // Dwell Confirmation Ring on Drag-Over
                if isTargetedForDrop && !item.isFolder {
                    ZStack {
                        // Background guide track
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 2.5)
                            .frame(width: appSettings.iconSize + 10, height: appSettings.iconSize + 10)
                        
                        // Animated filling circle driven strictly by real-time dwell timer
                        Circle()
                            .trim(from: 0, to: dwellProgress)
                            .stroke(
                                dwellProgress >= 0.95 ? Color.accentColor : Color.white,
                                style: StrokeStyle(lineWidth: dwellProgress >= 0.95 ? 3.5 : 2.5, lineCap: .round)
                            )
                            .frame(width: appSettings.iconSize + 10, height: appSettings.iconSize + 10)
                            .rotationEffect(.degrees(-90))
                    }
                } else if isTargetedForDrop && item.isFolder {
                    // For existing folders: instantly show glowing drop highlight
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2.5)
                        .frame(width: appSettings.iconSize + 10, height: appSettings.iconSize + 10)
                }
            }
            .frame(width: appSettings.iconSize + 8, height: appSettings.iconSize + 8)
            
            // Name
            if appSettings.showAppNames {
                Text(item.name)
                    .font(.system(size: appSettings.gridColumns >= 7 ? 9.0 : 10.0, weight: item.isFolder ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isHovered ? textColor : textColor.opacity(appSettings.theme == .lightGlass ? 1.0 : 0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, appSettings.showAppNames ? 2 : 0)
        .padding(.horizontal, 1)
        .rotationEffect(.degrees(appManager.isEditing ? 1.2 : 0))
        .animation(appManager.isEditing ? Animation.easeInOut(duration: 0.11).repeatForever(autoreverses: true) : .default, value: appManager.isEditing)
        .overlay(
            Group {
                if appManager.isEditing {
                    ZStack {
                        Circle()
                            .fill(appManager.selectedItems.contains(item.id) ? Color.blue : Color.white.opacity(0.35))
                            .frame(width: 18, height: 18)
                            .shadow(radius: 2)
                        if appManager.selectedItems.contains(item.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: 12, y: -12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .background(
            ZStack {
                if isTargetedForDrop && !item.isFolder && dwellProgress < 0.95 {
                    // White insertion indicator stick on left or right (reordering mode)
                    HStack {
                        if appManager.dropSideIsRight {
                            Spacer()
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 3.5)
                                .shadow(color: Color.black.opacity(0.6), radius: 2)
                        } else {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 3.5)
                                .shadow(color: Color.black.opacity(0.6), radius: 2)
                            Spacer()
                        }
                    }
                } else if isTargetedForDrop && (dwellProgress >= 0.95 || item.isFolder) {
                    // Folder creation / drop-in highlight (held until circle is full or existing folder)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardFillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 0.8)
                        )
                }
            }
        )
        .contentShape(Rectangle())
        .scaleEffect(!appManager.draggedItems.isEmpty ? (appManager.draggedItems.contains(item.id) ? 0.7 : 0.85) : 1.0)
        .opacity(appManager.isEditing && !appManager.selectedItems.contains(item.id) && !appManager.draggedItems.isEmpty ? 0.5 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).speed(2), value: appManager.draggedItems)
        .onLongPressGesture(minimumDuration: 0.3) {
            withAnimation {
                appManager.toggleSelection(itemId: item.id)
            }
        }
        .onHover { h in
            withAnimation(appSettings.animationStyle.spring) {
                isHovered = h
            }
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    if appManager.isEditing {
                        withAnimation {
                            appManager.toggleSelection(itemId: item.id)
                        }
                    } else if item.isFolder {
                        withAnimation(appSettings.animationStyle.spring) {
                            appManager.activeFolder = item
                        }
                    } else if let path = item.path {
                        onAppClick(path)
                    }
                }
        )
        .onDrag {
            // Normal mode: single app drag
            if !appManager.isEditing {
                appManager.draggedItemId = item.id
                appManager.draggedItems = [item.id]
                return NSItemProvider(object: item.id as NSString)
            }
            // Edit mode: only selected apps can drag, all selected move as bundle
            if appManager.isEditing && appManager.selectedItems.contains(item.id) {
                appManager.draggedItems = appManager.selectedItems
                return NSItemProvider(object: appManager.selectedItems.joined(separator: ",") as NSString)
            }
            // Unselected in edit mode: return empty provider = no drag
            return NSItemProvider()
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let isRight = location.x > (appSettings.iconSize / 2)
                if isTargetedForDrop {
                    appManager.dropSideIsRight = isRight
                }
            case .ended:
                break
            }
        }
        .onDrop(of: [UTType.plainText.identifier, UTType.text.identifier, UTType.utf8PlainText.identifier], isTargeted: $isTargetedForDrop) { providers in
            dwellTimer?.invalidate()
            dwellTimer = nil
            
            let isCircleFullyLoaded = dwellProgress >= 0.95
            dwellProgress = 0.0
            
            // In edit mode, don't accept drops onto unselected items
            if appManager.isEditing && !appManager.selectedItems.contains(item.id) {
                // Allow drops onto folders even in edit mode
                if !item.isFolder {
                    return false
                }
            }
            
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    let string = object as? String ?? ""
                    let sourceIds = Set(string.components(separatedBy: ",").filter { !$0.isEmpty })
                    let insertAfter = appManager.dropSideIsRight
                    
                    DispatchQueue.main.async {
                        withAnimation(appSettings.animationStyle.spring) {
                            if appSettings.sortMode == .alphabetical { appSettings.sortMode = .custom }
                            
                            if item.isFolder {
                                appManager.addMultipleItemsToFolder(sourceIds: sourceIds, folderId: item.id)
                            } else if isCircleFullyLoaded {
                                if let singleId = sourceIds.first {
                                    appManager.createFolder(with: singleId, onto: item.id)
                                }
                            } else {
                                // Not fully completed: Reorder items
                                appManager.moveMultipleItems(sourceIds: sourceIds, to: item.id, insertAfter: insertAfter)
                            }
                        }
                    }
                }
            }
            
            appManager.draggedItemId = nil
            appManager.draggedItems = []
            return true
        }
        .contextMenu {
            Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                withAnimation(appSettings.animationStyle.spring) {
                    appManager.toggleFavorite(itemId: item.id)
                }
            }
            
            Divider()
            
            if !item.isFolder, let path = item.path {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                
                Divider()
                
                Button("Set Custom Icon...") {
                    IconPackManager.shared.pickCustomIconForApp(appPath: path) {
                        appManager.filterItems()
                    }
                }
                
                if IconPackManager.shared.hasCustomIcon(for: path) {
                    Button("Restore Default Icon") {
                        IconPackManager.shared.removeCustomIcon(for: path)
                        appManager.filterItems()
                    }
                }
                
                Divider()
                
                Button("Delete App via AppCleaner...") {
                    Uninstaller.shared.uninstallApp(at: path)
                }
            } else if item.isFolder {
                Button("Delete Folder") {
                    withAnimation(appSettings.animationStyle.spring) {
                        appManager.deleteFolder(folderId: item.id)
                    }
                }
            }
            Divider()
            Button("Refresh Installed Apps") {
                appManager.refreshApps()
            }
        }
        .onChange(of: isTargetedForDrop) { targeted in
            dwellTimer?.invalidate()
            dwellTimer = nil
            
            if targeted {
                dwellProgress = 0.0
                
                if !item.isFolder {
                    // Start smooth timer: 18 ticks of 0.05s = 0.9s duration to fill the folder creation ring
                    let totalTicks: CGFloat = 18.0
                    var currentTick: CGFloat = 0.0
                    
                    let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                        currentTick += 1.0
                        let p = min(1.0, currentTick / totalTicks)
                        withAnimation(.linear(duration: 0.05)) {
                            dwellProgress = p
                        }
                        if p >= 1.0 {
                            t.invalidate()
                        }
                    }
                    RunLoop.main.add(timer, forMode: .common)
                    dwellTimer = timer
                } else if item.isFolder && !appManager.draggedItems.isEmpty {
                    // Hovering over a folder for 0.45s: auto open it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        if isTargetedForDrop && !appManager.draggedItems.isEmpty {
                            withAnimation(appSettings.animationStyle.spring) {
                                appManager.activeFolder = item
                            }
                        }
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    dwellProgress = 0.0
                }
            }
        }
    }
}

// MARK: - Page Indicator Dot
struct PageIndicatorDotView: View {
    let index: Int
    let currentPage: Int
    let accentColor: Color
    let textColor: Color
    let animationStyle: Animation
    var onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(currentPage == index ? accentColor : textColor.opacity(0.3))
            .frame(width: size, height: size)
            .animation(animationStyle, value: currentPage)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
            .onHover { h in isHovered = h }
            .onTapGesture(perform: onSelect)
            .contentShape(Circle())
    }

    private var size: CGFloat {
        if currentPage == index { return 10.0 }
        if isHovered { return 8.0 }
        return 6.0
    }
}

// MARK: - Folder Icon Preview
struct FolderIconPreviewView: View {
    let subPaths: [String]
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, y: 1.5)
            
            let previewPaths = Array(subPaths.prefix(4))
            
            if previewPaths.isEmpty {
                Image(systemName: "folder.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(Color.white.opacity(0.85))
            } else {
                let miniSize = max(11, size * 0.35)
                LazyVGrid(columns: [GridItem(.fixed(miniSize)), GridItem(.fixed(miniSize))], spacing: 2) {
                    ForEach(previewPaths, id: \.self) { path in
                        Image(nsImage: appManager.icon(for: path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: miniSize, height: miniSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Folder Modal Drawer View
struct FolderModalView: View {
    let folder: LaunchpadItem
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onClose: () -> Void
    var onAppLaunched: () -> Void
    
    @State private var folderName: String = ""
    @State private var showTransferSheet: Bool = false
    @State private var draggedFolderPath: String? = nil
    @State private var dropSideIsRight: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 14) {
                // Header
                HStack {
                    TextField("Folder Name", text: $folderName, onCommit: {
                        appManager.renameFolder(folderId: folder.id, newName: folderName)
                    })
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 120)
                    
                    // Folder Sort Mode
                    Button(action: {
                        withAnimation(appSettings.animationStyle.spring) {
                            appSettings.folderSortAlphabetical.toggle()
                        }
                    }) {
                        Image(systemName: appSettings.folderSortAlphabetical ? "textformat" : "hand.draw")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(appSettings.folderSortAlphabetical ? accentColor.opacity(0.2) : cardFillColor))
                            .overlay(Circle().stroke(cardStrokeColor, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Folder Sort")
                    
                    // Folder Grid Density
                    Button(action: {
                        withAnimation(appSettings.animationStyle.spring) {
                            if appSettings.folderGridColumns >= 5 {
                                appSettings.folderGridColumns = 3
                            } else {
                                appSettings.folderGridColumns += 1
                            }
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 9))
                            Text("\(appSettings.folderGridColumns)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(textColor.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(cardFillColor))
                        .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Change Folder Grid Density")
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(appSettings.animationStyle.spring) {
                            showTransferSheet.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11))
                            Text("Add Apps")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(textColor.opacity(appSettings.theme == .lightGlass ? 1.0 : 0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            Capsule()
                                .fill(cardFillColor)
                                .overlay(Capsule().stroke(cardStrokeColor, lineWidth: 0.6))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button("Delete Folder") {
                        withAnimation(appSettings.animationStyle.spring) {
                            appManager.deleteFolder(folderId: folder.id)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                Divider()
                    .background(textColor.opacity(0.15))
                
                // Apps Inside Folder
                let subPaths: [String] = {
                    let paths = folder.subAppPaths ?? []
                    if appSettings.folderSortAlphabetical {
                        return paths.sorted { p1, p2 in
                            let n1 = appManager.allAppsCache[p1]?.name ?? (p1 as NSString).lastPathComponent
                            let n2 = appManager.allAppsCache[p2]?.name ?? (p2 as NSString).lastPathComponent
                            return n1.localizedCaseInsensitiveCompare(n2) == .orderedAscending
                        }
                    }
                    return paths
                }()
                
                if subPaths.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 32))
                            .foregroundColor(textColor.opacity(0.3))
                        Text("This folder is empty")
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: appSettings.folderGridColumns), spacing: 12) {
                            ForEach(subPaths, id: \.self) { path in
                                let name = appManager.allAppsCache[path]?.name ?? (path as NSString).lastPathComponent
                                let isDraggingThis = draggedFolderPath == path
                                
                                VStack(spacing: 4) {
                                    Image(nsImage: appManager.icon(for: path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 40)
                                    
                                    Text(name)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(textColor)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(height: 28)
                                    
                                    Button("Remove") {
                                        withAnimation(appSettings.animationStyle.spring) {
                                            appManager.removeItemFromFolder(appPath: path, folderId: folder.id)
                                        }
                                    }
                                    .font(.system(size: 8))
                                    .foregroundColor(textColor.opacity(0.5))
                                    .buttonStyle(.plain)
                                }
                                .padding(6)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(cardFillColor)
                                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(cardStrokeColor, lineWidth: 0.6))
                                )
                                .opacity(isDraggingThis ? 0.5 : 1.0)
                                .scaleEffect(isDraggingThis ? 0.95 : 1.0)
                                .overlay(
                                    ZStack {
                                        if draggedFolderPath != nil && !dropSideIsRight && !isDraggingThis {
                                            HStack {
                                                Capsule()
                                                    .fill(Color.white)
                                                    .frame(width: 3.5, height: 50)
                                                    .shadow(color: Color.black.opacity(0.6), radius: 2)
                                                Spacer()
                                            }
                                            .padding(.leading, 2)
                                        }
                                        if draggedFolderPath != nil && dropSideIsRight && !isDraggingThis {
                                            HStack {
                                                Spacer()
                                                Capsule()
                                                    .fill(Color.white)
                                                    .frame(width: 3.5, height: 50)
                                                    .shadow(color: Color.black.opacity(0.6), radius: 2)
                                            }
                                            .padding(.trailing, 2)
                                        }
                                    }
                                )
                                .highPriorityGesture(
                                    TapGesture()
                                        .onEnded {
                                            appManager.launchApp(at: path) {
                                                onClose()
                                                onAppLaunched()
                                            }
                                        }
                                )
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        dropSideIsRight = location.x > 50
                                    case .ended:
                                        break
                                    }
                                }
                                .onDrag {
                                    draggedFolderPath = path
                                    return NSItemProvider(object: path as NSString)
                                }
                                .onDrop(of: [UTType.plainText.identifier, UTType.text.identifier, UTType.utf8PlainText.identifier], isTargeted: nil) { _ in
                                    guard let from = draggedFolderPath, from != path else {
                                        draggedFolderPath = nil
                                        return false
                                    }
                                    // Reorder inside folder
                                    withAnimation(appSettings.animationStyle.spring) {
                                        appManager.reorderInsideFolder(folderId: folder.id, fromPath: from, toPath: path)
                                    }
                                    draggedFolderPath = nil
                                    return true
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .frame(width: 400, height: 300)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.10).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 20, y: 10)
            )
            .onDrop(of: [UTType.plainText.identifier, UTType.text.identifier, UTType.utf8PlainText.identifier], isTargeted: nil) { providers in
                if let sourceId = appManager.draggedItemId {
                    appManager.draggedItemId = nil
                    withAnimation(appSettings.animationStyle.spring) {
                        appManager.addItemToFolder(sourceId: sourceId, folderId: folder.id)
                    }
                    return true
                }
                return false
            }
            
            if showTransferSheet {
                TransferAppsToFolderSheet(
                    appManager: appManager,
                    appSettings: appSettings,
                    folderId: folder.id,
                    textColor: textColor,
                    cardFillColor: cardFillColor,
                    cardStrokeColor: cardStrokeColor,
                    onClose: {
                        withAnimation(appSettings.animationStyle.spring) {
                            showTransferSheet = false
                        }
                    }
                )
            }
        }
        .onAppear {
            folderName = folder.name
        }
    }
}

// MARK: - Transfer Apps to Folder Sheet
struct TransferAppsToFolderSheet: View {
    @ObservedObject var appManager: AppDiscoveryManager
    @ObservedObject var appSettings: AppSettings
    let folderId: String
    let textColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onClose: () -> Void
    
    @State private var selectedAppIds: Set<String> = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Add Apps from Launcher")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                let availableApps = appManager.items.filter { $0.type == .app }
                
                if availableApps.isEmpty {
                    Text("No apps available in the launcher.")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(availableApps) { app in
                                HStack(spacing: 10) {
                                    if let path = app.path {
                                        Image(nsImage: appManager.icon(for: path))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                    }
                                    
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: selectedAppIds.contains(app.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedAppIds.contains(app.id) ? Color.accentColor : textColor.opacity(0.4))
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedAppIds.contains(app.id) ? Color.accentColor.opacity(0.15) : cardFillColor)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedAppIds.contains(app.id) {
                                        selectedAppIds.remove(app.id)
                                    } else {
                                        selectedAppIds.insert(app.id)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
                
                Button(action: {
                    withAnimation(appSettings.animationStyle.spring) {
                        for appId in selectedAppIds {
                            appManager.addItemToFolder(sourceId: appId, folderId: folderId)
                        }
                        onClose()
                    }
                }) {
                    Text("Add Selected to Folder")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(selectedAppIds.isEmpty)
                .opacity(selectedAppIds.isEmpty ? 0.5 : 1.0)
            }
            .padding(16)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.12).opacity(0.98))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardStrokeColor, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.5), radius: 15)
            )
        }
    }
}

// MARK: - Authentic Theme Background Styling (Colorless Apple Liquid Glass & More)
struct ThemeBackground: View {
    let theme: AppTheme
    let opacity: Double
    let shape: CustomRoundedShape
    var isHovered: Bool
    
    var body: some View {
        switch theme {
        case .liquidGlass:
            // TODO: replace with .glassEffect() when building with Xcode 26 SDK
            ZStack {
                shape.fill(LinearGradient(
                    colors: [Color(white: 0.14).opacity(opacity * 0.88), Color(white: 0.06).opacity(opacity * 0.96)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                shape.fill(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.16), location: 0.0),
                        .init(color: Color.white.opacity(0.04), location: 0.35),
                        .init(color: Color.clear, location: 0.75)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                shape.stroke(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(isHovered ? 0.90 : 0.75), location: 0.0),
                        .init(color: Color.white.opacity(0.35), location: 0.50),
                        .init(color: Color.white.opacity(0.12), location: 1.0)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 1.2)
                shape.stroke(Color.white.opacity(isHovered ? 0.22 : 0.12), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(isHovered ? 0.55 : 0.40), radius: isHovered ? 20 : 12, x: 2, y: 0)
        case .frostedGlass:
            shape
                .fill(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(opacity))
                .overlay(
                    shape.stroke(Color.white.opacity(isHovered ? 0.35 : 0.16), lineWidth: 0.8)
                )
                
        case .opaque:
            shape
                .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                .overlay(
                    shape.stroke(Color.white.opacity(isHovered ? 0.4 : 0.22), lineWidth: 1.0)
                )
                
        case .midnight:
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(opacity),
                            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(opacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    shape.stroke(
                        Color.cyan.opacity(isHovered ? 0.6 : 0.25),
                        lineWidth: 0.9
                    )
                )
                
        case .lightGlass:
            shape
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97).opacity(opacity))
                .overlay(
                    shape.stroke(Color.black.opacity(isHovered ? 0.25 : 0.12), lineWidth: 0.8)
                )
        }
    }
}

// MARK: - Welcoming Banner View
struct WelcomingBannerView: View {
    let textColor: Color
    let accentColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    var onDismiss: () -> Void
    
    @State private var shimmer: Bool = false
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning! ✨ Welcome to MiniPad"
        } else if hour < 18 {
            return "Good Afternoon! ✨ Welcome to MiniPad"
        } else {
            return "Good Evening! ✨ Welcome to MiniPad"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.yellow)
                .rotationEffect(.degrees(shimmer ? 360 : 0))
                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: shimmer)
            
            Text(greeting)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(textColor)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: accentColor.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            shimmer = true
        }
    }
}
