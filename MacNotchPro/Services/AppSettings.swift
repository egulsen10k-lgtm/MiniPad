//
//  AppSettings.swift
//  MiniPad
//

import SwiftUI
import AppKit
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case liquidGlass = "Liquid Glass"
    case frostedGlass = "Frosted Glass"
    case opaque = "Jet Black (Opaque)"
    case midnight = "Midnight Sapphire"
    case lightGlass = "Frosty Light"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .liquidGlass: return "Authentic Apple neutral fluid glass with pure specular reflections"
        case .frostedGlass: return "Classic dark macOS blur with subtle glass border"
        case .opaque: return "Solid deep jet-black matte finish"
        case .midnight: return "Deep sapphire dark glass with electric blue accents"
        case .lightGlass: return "Clean translucent light acrylic for bright desktops"
        }
    }
}

enum AnimationStyle: String, CaseIterable, Identifiable {
    case bouncy = "Bouncy"
    case smooth = "Smooth"
    case elegant = "Elegant"
    case snappy = "Snappy"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .bouncy: return "waveform.path.ecg"
        case .smooth: return "wind"
        case .elegant: return "sparkles"
        case .snappy: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .bouncy: return "Springy, lively bounce with playful recoil"
        case .smooth: return "Fluid, balanced standard macOS physics"
        case .elegant: return "Slow, graceful, silky luxury ease"
        case .snappy: return "Instant, ultra-responsive, sharp motion"
        }
    }
    
    var spring: Animation {
        switch self {
        case .bouncy: return .spring(response: 0.44, dampingFraction: 0.58, blendDuration: 0.2)
        case .smooth: return .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.15)
        case .elegant: return .spring(response: 0.52, dampingFraction: 0.90, blendDuration: 0.25)
        case .snappy: return .spring(response: 0.22, dampingFraction: 0.86, blendDuration: 0.05)
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case alphabetical = "Alphabetical (A-Z)"
    case custom = "Custom (Drag & Drop)"
    var id: String { rawValue }
}

enum HandleStyle: String, CaseIterable, Identifiable {
    case pill = "Classic Pill"
    case notch = "MacBook Notch"
    case mini = "Mini Style"
    case tab = "Floating Tab"
    case custom = "Custom Bar"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .pill: return "The standard sleek vertical pill with grip lines"
        case .notch: return "A hardware camera notch style curving out from the screen edge"
        case .mini: return "A super compact, minimal floating bar for a clean desktop"
        case .tab: return "A distinct floating tab card with high contrast and depth"
        case .custom: return "A fully customizable flexible bar with adjustable width and height"
        }
    }
}

enum ScreenEdge: String, CaseIterable, Identifiable {
    case left = "Left Edge"
    case right = "Right Edge"
    
    var id: String { rawValue }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("handleEdge") var handleEdgeRaw: String = ScreenEdge.left.rawValue {
        didSet { objectWillChange.send() }
    }
    
    var handleEdge: ScreenEdge {
        get { ScreenEdge(rawValue: handleEdgeRaw) ?? .left }
        set { handleEdgeRaw = newValue.rawValue }
    }
    
    @AppStorage("handleStyle") var handleStyleRaw: String = HandleStyle.pill.rawValue {
        didSet { objectWillChange.send() }
    }
    
    var handleStyle: HandleStyle {
        get { HandleStyle(rawValue: handleStyleRaw) ?? .pill }
        set { handleStyleRaw = newValue.rawValue }
    }
    
    // Theme
    @AppStorage("selectedTheme") var selectedThemeRaw: String = AppTheme.liquidGlass.rawValue {
        didSet { objectWillChange.send() }
    }
    
    var theme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .liquidGlass }
        set { selectedThemeRaw = newValue.rawValue }
    }
    
    // Icon Pack Style
    @AppStorage("iconPackStyle") var iconPackStyleRaw: String = IconPackStyle.original.rawValue {
        didSet {
            objectWillChange.send()
            IconPackManager.shared.clearCache()
        }
    }
    
    var iconPackStyle: IconPackStyle {
        get { IconPackStyle(rawValue: iconPackStyleRaw) ?? .original }
        set { iconPackStyleRaw = newValue.rawValue }
    }
    
    // Animation Style
    @AppStorage("animationStyle") var animationStyleRaw: String = AnimationStyle.smooth.rawValue {
        didSet { objectWillChange.send() }
    }
    
    var animationStyle: AnimationStyle {
        get { AnimationStyle(rawValue: animationStyleRaw) ?? .smooth }
        set { animationStyleRaw = newValue.rawValue }
    }
    
    // App Sort Mode
    @AppStorage("sortMode") var sortModeRaw: String = SortMode.custom.rawValue {
        didSet {
            objectWillChange.send()
            AppDiscoveryManager.shared.filterItems()
        }
    }
    
    var sortMode: SortMode {
        get { SortMode(rawValue: sortModeRaw) ?? .custom }
        set { sortModeRaw = newValue.rawValue }
    }
    
    // Screen Selection
    @AppStorage("selectedScreenIndex") var selectedScreenIndex: Int = 0 {
        didSet { objectWillChange.send() }
    }
    
    // Grid Customization (Columns & Rows per section)
    @AppStorage("gridColumns") var gridColumns: Int = 5 {
        didSet {
            objectWillChange.send()
            AppDiscoveryManager.shared.filterItems()
        }
    }
    
    @AppStorage("gridRows") var gridRows: Int = 3 {
        didSet {
            objectWillChange.send()
            AppDiscoveryManager.shared.filterItems()
        }
    }

    // Toggle to display seconds in the digital clock widget
    @AppStorage("showClockSeconds") var showClockSeconds: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    // Toggle for welcoming animation / greeting banner when opening MiniPad
    @AppStorage("showWelcomeMessage") var showWelcomeMessage: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // Toggle for Spotify/Music widget album art background
    @AppStorage("useAlbumColorWidget") var useAlbumColorWidget: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    var itemsPerPage: Int {
        max(4, gridColumns * gridRows)
    }
    
    // Responsive adaptive dimensions based on density
    var launchpadWidth: CGFloat {
        switch gridColumns {
        case ...3: return 530
        case 4:    return 620
        case 5:    return 710
        case 6:    return 800
        case 7:    return 890
        default:   return 970 // 8
        }
    }
    
    var launchpadHeight: CGFloat {
        let currentItemsCount = AppDiscoveryManager.shared.itemsForCurrentPage().count
        let effectiveRows: Int
        if currentItemsCount <= 0 {
            effectiveRows = 1
        } else {
            effectiveRows = min(gridRows, max(1, (currentItemsCount + gridColumns - 1) / gridColumns))
        }

        let rowHeight: CGFloat = showAppNames ? 86 : 72
        let headerHeight: CGFloat = 85
        let footerHeight: CGFloat = 45
        let musicBarHeight: CGFloat = 52 // music player bar
        let total = headerHeight + CGFloat(effectiveRows) * rowHeight + footerHeight + musicBarHeight
        return max(280, total)
    }
    
    var iconSize: CGFloat {
        let maxDim = max(gridColumns, gridRows + 1)
        switch maxDim {
        case ...4: return 64
        case 5:    return 60
        case 6:    return 56
        case 7:    return 50
        default:   return 44
        }
    }
    
    // Left edge handle dimensions
    @AppStorage("handleWidth") var handleWidth: Double = 14.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("handleHeight") var handleHeight: Double = 120.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("handleCornerRadius") var handleCornerRadius: Double = 10.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("yOffset") var yOffset: Double = 0.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("handleVerticalPosition") var handleVerticalPosition: Double = 300.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("bgOpacity") var bgOpacity: Double = 0.88 {
        didSet { objectWillChange.send() }
    }
    
    // Behaviors
    @AppStorage("expandOnHover") var expandOnHover: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("autoCloseOnLaunch") var autoCloseOnLaunch: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("scrollPaginationEnabled") var scrollPaginationEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            objectWillChange.send()
            LoginItemManager.shared.isLaunchAtLoginEnabled = launchAtLogin
        }
    }
    
    @AppStorage("showAppNames") var showAppNames: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("enableDockHoverEffect") var enableDockHoverEffect: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // Folder Settings
    @AppStorage("folderGridColumns") var folderGridColumns: Int = 4 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("folderSortAlphabetical") var folderSortAlphabetical: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // Vault Preferences
    @AppStorage("vaultPassword") var vaultPassword: String = "0000" {
        didSet { objectWillChange.send() }
    }
    
    @Published var isVaultUnlocked: Bool = false
    
    func getConnectedScreens() -> [(index: Int, name: String, resolution: String, isMain: Bool)] {
        return NSScreen.screens.enumerated().map { index, screen in
            let name = screen.localizedName
            let res = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
            let isMain = screen == NSScreen.main
            return (index, name, res, isMain)
        }
    }
    
    func resetToDefaults() {
        selectedThemeRaw = AppTheme.liquidGlass.rawValue
        iconPackStyleRaw = IconPackStyle.original.rawValue
        animationStyleRaw = AnimationStyle.smooth.rawValue
        sortModeRaw = SortMode.custom.rawValue
        selectedScreenIndex = 0
        gridColumns = 5
        gridRows = 3
        handleWidth = 14.0
        handleHeight = 120.0
        handleCornerRadius = 10.0
        yOffset = 0.0
        bgOpacity = 0.88
        expandOnHover = true
        autoCloseOnLaunch = true
        scrollPaginationEnabled = true
        launchAtLogin = false
        showAppNames = true
        objectWillChange.send()
        IconPackManager.shared.clearCache()
        AppDiscoveryManager.shared.filterItems()
    }
}
