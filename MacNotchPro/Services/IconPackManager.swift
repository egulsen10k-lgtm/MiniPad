//
//  IconPackManager.swift
//  MiniPad
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum IconPackStyle: String, CaseIterable, Identifiable, Codable {
    case original = "Original (Native)"
    case dark = "Dark Onyx"
    case light = "Frosty Light"
    case glass = "Liquid Glass"
    case custom = "Custom Pack"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .original: return "sparkles"
        case .dark:     return "moon.fill"
        case .light:    return "sun.max.fill"
        case .glass:    return "drop.fill"
        case .custom:   return "folder.badge.gearshape"
        }
    }
    
    var description: String {
        switch self {
        case .original:
            return "Standard full-color vibrant macOS application icons"
        case .dark:
            return "Sleek dark obsidian squircles with crisp specular rim"
        case .light:
            return "Clean porcelain white squircles with smooth bevel"
        case .glass:
            return "Translucent fluid crystal glass squircles"
        case .custom:
            return "Load custom icons from folder or individual app overrides"
        }
    }
}

class IconPackManager: ObservableObject {
    static let shared = IconPackManager()
    
    private let overridesKey = "MiniPad_CustomIconOverrides_V1"
    private let customFolderKey = "MiniPad_CustomIconFolder_V1"
    
    @Published var customOverrides: [String: String] = [:] // appPath -> customImagePath
    @Published var customFolderURL: URL
    
    // In-memory icon cache for instant 120fps launchpad scrolling
    private var renderedCache = NSCache<NSString, NSImage>()
    
    init() {
        // Initialize default custom folder
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultIconsDir = appSupport.appendingPathComponent("MiniPad/CustomIcons", isDirectory: true)
        
        try? fileManager.createDirectory(at: defaultIconsDir, withIntermediateDirectories: true, attributes: nil)
        
        if let savedPath = UserDefaults.standard.string(forKey: customFolderKey),
           fileManager.fileExists(atPath: savedPath) {
            self.customFolderURL = URL(fileURLWithPath: savedPath)
        } else {
            self.customFolderURL = defaultIconsDir
        }
        
        if let savedOverrides = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] {
            self.customOverrides = savedOverrides
        }
    }
    
    func clearCache() {
        renderedCache.removeAllObjects()
        objectWillChange.send()
    }
    
    // MARK: - Custom Icon Overrides
    func setCustomIcon(for appPath: String, imageURL: URL) {
        // Copy image into App Support to ensure persistent access
        let fileManager = FileManager.default
        let ext = imageURL.pathExtension
        let safeName = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let targetFileName = "\(safeName)_\(UUID().uuidString.prefix(8)).\(ext)"
        let targetURL = customFolderURL.appendingPathComponent(targetFileName)
        
        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try? fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: imageURL, to: targetURL)
            customOverrides[appPath] = targetURL.path
            UserDefaults.standard.set(customOverrides, forKey: overridesKey)
            clearCache()
        } catch {
            print("Failed to save custom icon: \(error.localizedDescription)")
            customOverrides[appPath] = imageURL.path
            UserDefaults.standard.set(customOverrides, forKey: overridesKey)
            clearCache()
        }
    }
    
    func removeCustomIcon(for appPath: String) {
        if let currentPath = customOverrides[appPath] {
            if currentPath.contains("MiniPad/CustomIcons") {
                try? FileManager.default.removeItem(atPath: currentPath)
            }
            customOverrides.removeValue(forKey: appPath)
            UserDefaults.standard.set(customOverrides, forKey: overridesKey)
            clearCache()
        }
    }
    
    func hasCustomIcon(for appPath: String) -> Bool {
        return customOverrides[appPath] != nil
    }
    
    func clearAllCustomOverrides() {
        customOverrides.removeAll()
        UserDefaults.standard.set(customOverrides, forKey: overridesKey)
        clearCache()
    }
    
    // MARK: - Native File Pickers
    func pickCustomIconForApp(appPath: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            let panel = NSOpenPanel()
            panel.title = "Select Custom App Icon"
            panel.prompt = "Set Icon"
            panel.allowedContentTypes = [
                UTType.png,
                UTType.image,
                UTType.icns,
                UTType.jpeg,
                UTType.webP
            ]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canCreateDirectories = false
            panel.level = .floating
            
            if panel.runModal() == .OK, let url = panel.url {
                self.setCustomIcon(for: appPath, imageURL: url)
            }
            
            if !SettingsWindowManager.shared.isSettingsOpen {
                NSApp.setActivationPolicy(.accessory)
            }
            completion?()
        }
    }
    
    func chooseCustomPackFolder(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            let panel = NSOpenPanel()
            panel.title = "Select Custom Icon Pack Directory"
            panel.prompt = "Choose Folder"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.level = .floating
            
            if panel.runModal() == .OK, let url = panel.url {
                self.customFolderURL = url
                UserDefaults.standard.set(url.path, forKey: self.customFolderKey)
                self.clearCache()
            }
            
            if !SettingsWindowManager.shared.isSettingsOpen {
                NSApp.setActivationPolicy(.accessory)
            }
            completion?()
        }
    }
    
    func openCustomIconsFolderInFinder() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: customFolderURL.path) {
            try? fileManager.createDirectory(at: customFolderURL, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([customFolderURL])
    }
    
    // MARK: - Icon Rendering Engine
    func icon(
        for appPath: String,
        appName: String,
        bundleId: String,
        style: IconPackStyle,
        defaultIcon: NSImage
    ) -> NSImage {
        let cacheKey = "\(appPath)_\(style.rawValue)" as NSString
        if let cached = renderedCache.object(forKey: cacheKey) {
            return cached
        }
        
        // 1. Direct Individual Override Check
        if let overridePath = customOverrides[appPath],
           let overrideImage = NSImage(contentsOfFile: overridePath) {
            overrideImage.size = NSSize(width: 64, height: 64)
            renderedCache.setObject(overrideImage, forKey: cacheKey)
            return overrideImage
        }
        
        // 2. Custom Pack Directory Check (matches AppName.png, bundleId.png, etc.)
        if style == .custom || customFolderContainsIcon(appName: appName, bundleId: bundleId) {
            if let folderIcon = findIconInCustomFolder(appName: appName, bundleId: bundleId) {
                renderedCache.setObject(folderIcon, forKey: cacheKey)
                return folderIcon
            }
        }
        
        // 3. Style-Based Rendering
        let finalImage: NSImage
        switch style {
        case .original:
            finalImage = defaultIcon
            
        case .dark:
            finalImage = renderStyledSquircleIcon(
                baseIcon: defaultIcon,
                backgroundColor: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
                borderColor: NSColor(calibratedWhite: 1.0, alpha: 0.18),
                borderWidth: 1.2,
                shadowColor: NSColor.black.withAlphaComponent(0.4),
                iconScale: 0.72
            )
            
        case .light:
            finalImage = renderStyledSquircleIcon(
                baseIcon: defaultIcon,
                backgroundColor: NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.96, alpha: 1.0),
                borderColor: NSColor(calibratedWhite: 0.0, alpha: 0.12),
                borderWidth: 1.0,
                shadowColor: NSColor.black.withAlphaComponent(0.2),
                iconScale: 0.72
            )
            
        case .glass:
            finalImage = renderStyledSquircleIcon(
                baseIcon: defaultIcon,
                backgroundColor: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.24, alpha: 0.75),
                borderColor: NSColor(calibratedWhite: 1.0, alpha: 0.45),
                borderWidth: 1.4,
                shadowColor: NSColor.black.withAlphaComponent(0.35),
                iconScale: 0.72
            )
            
        case .custom:
            finalImage = defaultIcon
        }
        
        finalImage.size = NSSize(width: 64, height: 64)
        renderedCache.setObject(finalImage, forKey: cacheKey)
        return finalImage
    }
    
    private func customFolderContainsIcon(appName: String, bundleId: String) -> Bool {
        return findIconInCustomFolder(appName: appName, bundleId: bundleId) != nil
    }
    
    private func findIconInCustomFolder(appName: String, bundleId: String) -> NSImage? {
        let fileManager = FileManager.default
        let folder = customFolderURL.path
        
        let candidateNames = [
            appName,
            appName.lowercased(),
            appName.replacingOccurrences(of: " ", with: ""),
            bundleId,
            bundleId.lowercased(),
            (bundleId as NSString).lastPathComponent
        ]
        
        let extensions = ["png", "icns", "jpg", "jpeg", "webp", "tiff"]
        
        for name in candidateNames where !name.isEmpty {
            for ext in extensions {
                let filePath = "\(folder)/\(name).\(ext)"
                if fileManager.fileExists(atPath: filePath),
                   let img = NSImage(contentsOfFile: filePath) {
                    img.size = NSSize(width: 64, height: 64)
                    return img
                }
            }
        }
        return nil
    }
    
    // MARK: - Core Graphics Squircle Generator
    private func renderStyledSquircleIcon(
        baseIcon: NSImage,
        backgroundColor: NSColor,
        borderColor: NSColor,
        borderWidth: CGFloat,
        shadowColor: NSColor,
        iconScale: CGFloat
    ) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return baseIcon
        }
        
        ctx.saveGState()
        
        let canvasRect = CGRect(origin: .zero, size: size)
        let inset: CGFloat = 3.0
        let squircleRect = canvasRect.insetBy(dx: inset, dy: inset)
        let cornerRadius: CGFloat = squircleRect.width * 0.225
        
        let path = CGPath(
            roundedRect: squircleRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        // 1. Draw Drop Shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -2),
            blur: 4,
            color: shadowColor.cgColor
        )
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()
        
        // 2. Draw Squircle Background
        ctx.addPath(path)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillPath()
        
        // 3. Draw Inner Specular Glaze / Top Highlight
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        
        let highlightGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.18).cgColor,
                NSColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray,
            locations: [0.0, 0.45]
        )
        if let grad = highlightGradient {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
                end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
                options: []
            )
        }
        
        // 4. Draw Scaled Base Icon in Center
        let iconW = squircleRect.width * iconScale
        let iconH = squircleRect.height * iconScale
        let iconX = squircleRect.origin.x + (squircleRect.width - iconW) / 2
        let iconY = squircleRect.origin.y + (squircleRect.height - iconH) / 2
        let iconRect = NSRect(x: iconX, y: iconY, width: iconW, height: iconH)
        
        baseIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        ctx.restoreGState()
        
        // 5. Draw Outer Specular Border
        ctx.addPath(path)
        ctx.setLineWidth(borderWidth)
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.strokePath()
        
        ctx.restoreGState()
        image.unlockFocus()
        
        return image
    }
}
