#!/bin/bash
set -e

APP_NAME="Speuge"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🚀 Building ${APP_NAME} via Xcode (Release)..."
xcodebuild build -project Speuge.xcodeproj -scheme Speuge -configuration Release CONFIGURATION_BUILD_DIR="${PWD}/build" CODE_SIGNING_ALLOWED=NO -quiet

echo "📦 Preparing ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
cp -R "build/${BUNDLE_DIR}" .

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
