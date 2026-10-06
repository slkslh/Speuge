#!/bin/bash
set -e

APP_NAME="NetworkSpeed"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🚀 Building ${APP_NAME} Universal Binary (Apple Silicon + Intel)..."
swift build -c release --arch arm64 --arch x86_64

echo "📦 Assembling ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy universal binary
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
if [ -f "${BIN_PATH}/${APP_NAME}" ]; then
    cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
elif [ -f ".build/out/Products/Release/${APP_NAME}" ]; then
    cp ".build/out/Products/Release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
fi
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "AppResources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy AppIcon.icns
if [ -f "AppResources/AppIcon.icns" ]; then
    cp "AppResources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Ad-hoc code signing
echo "✍️ Signing application bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

# Create shareable ZIP and professional DMG packages
echo "🗜️ Creating ZIP archive..."
rm -f "${APP_NAME}.zip"
ditto -c -k --sequesterRsrc --keepParent "${BUNDLE_DIR}" "${APP_NAME}.zip"

# Create professional Drag-to-Applications DMG installer
./package_dmg.sh

echo "✅ Successfully built ${BUNDLE_DIR}!"
echo "🎁 Shareable packages ready:"
echo "   - ${APP_NAME}.dmg (Professional Drag-and-Drop Mac Installer)"
echo "   - ${APP_NAME}.zip (Send via AirDrop, Email, WhatsApp, Drive, etc.)"

if [ "$1" == "--install" ]; then
    echo "📲 Installing to /Applications..."
    rm -rf "/Applications/${BUNDLE_DIR}"
    cp -R "${BUNDLE_DIR}" "/Applications/"
    echo "✨ Installed to /Applications/${BUNDLE_DIR}"
elif [ "$1" == "--run" ]; then
    echo "▶️ Launching ${APP_NAME}..."
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 0.5
    open "${BUNDLE_DIR}"
fi
