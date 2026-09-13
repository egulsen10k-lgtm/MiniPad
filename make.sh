#!/bin/bash
set -e

# Configuration
APP_NAME="MiniPad"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${BUILD_DIR}/${APP_NAME}-Installer.dmg"
BACKGROUND_IMAGE="${BUILD_DIR}/dmg_background.tiff"

echo "🚀 Building professional DMG for ${APP_NAME}..."

# 1. Clean previous build artifacts
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. Build release binary
swift build -c release

# 3. Construct .app bundle
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp .build/release/MiniPad "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 4. Update Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.minipad.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 5. Generate gorgeous custom background image using Swift
echo "🎨 Generating DMG background artwork..."
swift create_dmg_background.swift

# 6. Create modern Drag-to-Install DMG using create-dmg
rm -f "${DMG_NAME}"

if command -v create-dmg &> /dev/null; then
    create-dmg \
      --volname "${APP_NAME} Installer" \
      --background "${BACKGROUND_IMAGE}" \
      --window-pos 200 120 \
      --window-size 660 400 \
      --icon-size 96 \
      --text-size 13 \
      --icon "${APP_NAME}.app" 180 200 \
      --app-drop-link 480 200 \
      "${DMG_NAME}" \
      "${APP_BUNDLE}"
else
    echo "⚠️ create-dmg not found, falling back to standard hdiutil DMG..."
    mkdir -p "${BUILD_DIR}/dmg_root"
    cp -R "${APP_BUNDLE}" "${BUILD_DIR}/dmg_root/"
    ln -s /Applications "${BUILD_DIR}/dmg_root/Applications"
    hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${BUILD_DIR}/dmg_root" -ov -format UDZO "${DMG_NAME}"
    rm -rf "${BUILD_DIR}/dmg_root"
fi

echo "✅ Done! Professional drag-to-install DMG available at ${BUILD_DIR}/"
ls -lh "${BUILD_DIR}"
