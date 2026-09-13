# MiniPad — Left Edge Launchpad

A customizable native macOS Left-Edge Launchpad with categorized smart tabs, authentic Colorless Apple Liquid Glass aesthetic, adaptive responsive UI sizing for any grid density, in-launcher grid density customization popover, 4 animation physics styles (Bouncy, Smooth, Elegant, Snappy), drag-and-drop folders with dwell confirmation, scroll-to-paginate gesture support with modal scroll lock, AppCleaner.app integration & redirect, and multi-screen monitor selection.

## 🎬 Flawless Reactive Animation Pipeline (`LaunchpadState`)

- **Persistent Single View Hierarchy**: Eliminated `rootView` re-assignment inside AppKit `NSHostingView`. SwiftUI now preserves its rendering hierarchy permanently, eliminating interrupted, dropped, or glitching spring animations.
- **Synchronized State Bridge**: `LaunchpadState.shared` coordinates drawer expansion, pin states, key window elevation, and spring physics natively.
- **Crossfading Page & Grid Transitions**: Smooth `.transition(.opacity.combined(with: .scale(scale: 0.98)))` animations when flipping pages, searching, or switching category tabs.

## 💎 Authentic Colorless Apple Liquid Glass Design

- **Pure Neutral Optical Substrate**: Translucent neutral dark crystal glass base without artificial color tinting.
- **Specular White Surface Glaze**: Diagonal light reflection and caustics replicating real polished glass.
- **Crisp Meniscus Rim Highlight**: Pure crisp white specular edge line where light catches the curved rounded fillet.
- **Pure Neutral Frosted Controls**: Active tabs, badges, and search well are styled in neutral frosted glass.
- **Vibrant Native App Icons**: Application icons retain 100% of their original, vibrant, high-definition macOS colors.

## 📐 Adaptive Responsive UI Sizing (Zero Truncation)

- **Dynamic Container Sizing**: Whether you select `3×2` (compact 530×400), `4×3`, `5×3`, `6×4`, or `8×6` (expanded 970×725), the Launchpad dynamically resizes its frame, icon dimensions, and vertical spacing.
- **Zero Truncation**: No items, tabs, search bars, or pagination buttons get cut off when reducing or increasing rows and columns.
- **Expanded NSPanel Canvas**: Accommodates all grid layout permutations seamlessly.

## 🔒 Modal & Overlay Scroll-Lock

- Whenever the **Grid Density popup modal**, **Folder popover**, or **Settings window** is active, background scroll wheel pagination is locked so internal controls can be adjusted without triggering page flips.

## 🛠️ Build & Run

```bash
cd /Users/emincanglsn/Documents/noch/MiniPad
swift build
swift run
```
