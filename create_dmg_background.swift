#!/usr/bin/env swift
import Cocoa

let width: CGFloat = 640
let height: CGFloat = 400
let backgroundColor = NSColor(white: 0.08, alpha: 1.0) // Dark charcoal
let accentColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // macOS blue
let lightAccentColor = NSColor(red: 0.3, green: 0.65, blue: 1.0, alpha: 1.0)
let textColor = NSColor.white
let subtitleColor = NSColor(white: 0.7, alpha: 1.0)

let size = NSSize(width: width, height: height)
let image = NSImage(size: size)
image.lockFocus()

// Background
backgroundColor.setFill()
NSBezierPath.fill(NSRect(origin: .zero, size: size))

// Subtle gradient overlay
let gradient = NSGradient(colors: [
    NSColor(white: 0.15, alpha: 0.3),
    NSColor(white: 0.05, alpha: 0.5),
    NSColor(white: 0.0, alpha: 0.6)
], atLocations: [0.0, 0.5, 1.0], colorSpace: NSColorSpace.deviceRGB)!
gradient.draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Subtle radial highlight in center
let radialPath = NSBezierPath(ovalIn: NSRect(x: width/2 - 180, y: height/2 - 80, width: 360, height: 160))
let radialGradient = NSGradient(colors: [
    accentColor.withAlphaComponent(0.08),
    NSColor.clear
], atLocations: [0.0, 1.0], colorSpace: NSColorSpace.deviceRGB)!
radialGradient.draw(in: radialPath, angle: 0)

// App icon placeholder area (left side)
let iconSize: CGFloat = 128
let iconX: CGFloat = 140
let iconY: CGFloat = height/2 - iconSize/2

// Icon background glow
let glowPath = NSBezierPath(roundedRect: NSRect(x: iconX - 8, y: iconY - 8, width: iconSize + 16, height: iconSize + 16), xRadius: 28, yRadius: 28)
let glowGradient = NSGradient(colors: [
    accentColor.withAlphaComponent(0.25),
    NSColor.clear
], atLocations: [0.0, 1.0])!
glowGradient.draw(in: glowPath, angle: -90)

// Icon rounded square background
let iconBgPath = NSBezierPath(roundedRect: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize), xRadius: 24, yRadius: 24)
let iconBgGradient = NSGradient(colors: [
    NSColor(white: 0.15, alpha: 1.0),
    NSColor(white: 0.08, alpha: 1.0)
], atLocations: [0.0, 1.0])!
iconBgGradient.draw(in: iconBgPath, angle: 90)

// Icon border
NSColor(white: 1.0, alpha: 0.15).setStroke()
iconBgPath.lineWidth = 1.5
iconBgPath.stroke()

// Launchpad grid icon inside
let gridSize: CGFloat = 72
let gridX = iconX + (iconSize - gridSize)/2
let gridY = iconY + (iconSize - gridSize)/2
let cellSize = gridSize / 3.5
let spacing = gridSize / 3.5 / 3.5

for row in 0..<3 {
    for col in 0..<3 {
        let cellRect = NSRect(
            x: gridX + CGFloat(col) * (cellSize + spacing) + spacing,
            y: gridY + CGFloat(2 - row) * (cellSize + spacing) + spacing,
            width: cellSize,
            height: cellSize
        )
        let cellPath = NSBezierPath(roundedRect: cellRect, xRadius: 6, yRadius: 6)
        let cellGradient = NSGradient(colors: [
            NSColor(white: 0.25, alpha: 1.0),
            NSColor(white: 0.15, alpha: 1.0)
        ], atLocations: [0.0, 1.0])!
        cellGradient.draw(in: cellPath, angle: 90)
        
        // Cell highlight
        let highlightPath = NSBezierPath(roundedRect: NSRect(x: cellRect.minX + 2, y: cellRect.maxY - 2 - cellSize/4, width: cellSize - 4, height: cellSize/4), xRadius: 3, yRadius: 3)
        NSColor(white: 1.0, alpha: 0.08).setFill()
        highlightPath.fill()
    }
}

// App name
let appName = "MiniPad"
let nameFont = NSFont.systemFont(ofSize: 32, weight: .bold)
let nameAttributes: [NSAttributedString.Key: Any] = [
    .font: nameFont,
    .foregroundColor: textColor,
    .kern: 1.5
]
let nameSize = appName.size(withAttributes: nameAttributes)
appName.draw(at: NSPoint(x: iconX + iconSize/2 - nameSize.width/2, y: iconY + iconSize + 20), withAttributes: nameAttributes)

// Subtitle
let subtitle = "Native macOS Launchpad"
let subtitleFont = NSFont.systemFont(ofSize: 14, weight: .medium)
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: subtitleColor,
    .kern: 0.5
]
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
subtitle.draw(at: NSPoint(x: iconX + iconSize/2 - subtitleSize.width/2, y: iconY + iconSize + 56), withAttributes: subtitleAttributes)

// Version badge
let version = "v1.0"
let versionFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
let versionAttributes: [NSAttributedString.Key: Any] = [
    .font: versionFont,
    .foregroundColor: accentColor,
    .kern: 0.5
]
let versionSize = version.size(withAttributes: versionAttributes)
let versionX = iconX + iconSize/2 - versionSize.width/2 - 8
let versionY = iconY + iconSize + 84
let versionBgRect = NSRect(x: versionX, y: versionY, width: versionSize.width + 16, height: versionSize.height + 6)
let versionBgPath = NSBezierPath(roundedRect: versionBgRect, xRadius: 4, yRadius: 4)
accentColor.withAlphaComponent(0.15).setFill()
versionBgPath.fill()
accentColor.withAlphaComponent(0.3).setStroke()
versionBgPath.lineWidth = 1
versionBgPath.stroke()
version.draw(at: NSPoint(x: versionX + 8, y: versionY + 3), withAttributes: versionAttributes)

// Right side: Arrow and Applications folder
let arrowStartX = iconX + iconSize + 60
let arrowEndX = width - 140
let arrowY = height/2 + 10

// Animated-style arrow
let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 30, y: arrowY))
arrowPath.lineWidth = 4
NSColor(white: 1.0, alpha: 0.2).setStroke()
arrowPath.setLineDash([12, 8], count: 2, phase: 0)
arrowPath.stroke()

// Arrow head
let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: arrowEndX - 30, y: arrowY - 12))
headPath.line(to: NSPoint(x: arrowEndX - 10, y: arrowY))
headPath.line(to: NSPoint(x: arrowEndX - 30, y: arrowY + 12))
headPath.close()
accentColor.setFill()
headPath.fill()

// Applications folder icon area
let folderSize: CGFloat = 96
let folderX = arrowEndX + 10
let folderY = height/2 - folderSize/2

// Folder glow
let folderGlowPath = NSBezierPath(roundedRect: NSRect(x: folderX - 8, y: folderY - 8, width: folderSize + 16, height: folderSize + 16), xRadius: 22, yRadius: 22)
let folderGlowGradient = NSGradient(colors: [
    NSColor.systemBlue.withAlphaComponent(0.2),
    NSColor.clear
], atLocations: [0.0, 1.0])!
folderGlowGradient.draw(in: folderGlowPath, angle: -90)

// Folder body
let folderBodyPath = NSBezierPath(roundedRect: NSRect(x: folderX, y: folderY + 16, width: folderSize, height: folderSize - 16), xRadius: 12, yRadius: 12)
let folderBodyGradient = NSGradient(colors: [
    NSColor.systemBlue.blended(withFraction: 0.3, of: NSColor.white)!,
    NSColor.systemBlue
], atLocations: [0.0, 1.0])!
folderBodyGradient.draw(in: folderBodyPath, angle: 90)

// Folder tab
let tabPath = NSBezierPath()
tabPath.move(to: NSPoint(x: folderX + 12, y: folderY + folderSize - 16))
tabPath.line(to: NSPoint(x: folderX + 12, y: folderY + folderSize + 4))
tabPath.curve(to: NSPoint(x: folderX + 44, y: folderY + folderSize + 4),
              controlPoint1: NSPoint(x: folderX + 12, y: folderY + folderSize + 14),
              controlPoint2: NSPoint(x: folderX + 44, y: folderY + folderSize + 14))
tabPath.line(to: NSPoint(x: folderX + 44, y: folderY + folderSize - 16))
tabPath.close()
let tabGradient = NSGradient(colors: [
    NSColor.systemBlue.blended(withFraction: 0.2, of: NSColor.white)!,
    NSColor.systemBlue
], atLocations: [0.0, 1.0])!
tabGradient.draw(in: tabPath, angle: 90)

// Folder highlight
let folderHighlightPath = NSBezierPath(roundedRect: NSRect(x: folderX + 6, y: folderY + folderSize - 20, width: folderSize - 12, height: 10), xRadius: 5, yRadius: 5)
NSColor(white: 1.0, alpha: 0.15).setFill()
folderHighlightPath.fill()

// "Applications" label
let appLabel = "Applications"
let labelFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
let labelAttributes: [NSAttributedString.Key: Any] = [
    .font: labelFont,
    .foregroundColor: textColor
]
let labelSize = appLabel.size(withAttributes: labelAttributes)
appLabel.draw(at: NSPoint(x: folderX + folderSize/2 - labelSize.width/2, y: folderY - 30), withAttributes: labelAttributes)

// Drag instruction text
let dragText = "Drag MiniPad to Applications"
let dragFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let dragAttributes: [NSAttributedString.Key: Any] = [
    .font: dragFont,
    .foregroundColor: subtitleColor
]
let dragSize = dragText.size(withAttributes: dragAttributes)
dragText.draw(at: NSPoint(x: folderX + folderSize/2 - dragSize.width/2, y: folderY + folderSize + 14), withAttributes: dragAttributes)

// Small arrow hint
let hintArrow = "↓"
let hintFont = NSFont.systemFont(ofSize: 18, weight: .bold)
let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: hintFont,
    .foregroundColor: accentColor
]
let hintSize = hintArrow.size(withAttributes: hintAttributes)
hintArrow.draw(at: NSPoint(x: folderX + folderSize/2 - hintSize.width/2, y: folderY + folderSize + 36), withAttributes: hintAttributes)

// Bottom subtle credits
let bottomText = "Designed for macOS 13+  •  Universal Binary  •  No Telemetry"
let bottomFont = NSFont.systemFont(ofSize: 10, weight: .regular)
let bottomAttributes: [NSAttributedString.Key: Any] = [
    .font: bottomFont,
    .foregroundColor: NSColor(white: 0.45, alpha: 1.0),
    .kern: 0.3
]
let bottomSize = bottomText.size(withAttributes: bottomAttributes)
bottomText.draw(at: NSPoint(x: width/2 - bottomSize.width/2, y: 18), withAttributes: bottomAttributes)

// Corner decorative elements
let cornerSize: CGFloat = 3
for (cx, cy) in [(30, 30), (width - 30, 30), (30, height - 30), (width - 30, height - 30)] {
    let cornerRect = NSRect(x: cx, y: cy, width: cornerSize, height: cornerSize)
    let cornerPath = NSBezierPath(roundedRect: cornerRect, xRadius: 1.5, yRadius: 1.5)
    accentColor.withAlphaComponent(0.4).setFill()
    cornerPath.fill()
}

image.unlockFocus()

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "/Users/emincanglsn/Documents/noch/MacNotchPro/assets/dmg/background.png")
    try? pngData.write(to: url)
    print("✅ Background image created at \(url.path)")
}