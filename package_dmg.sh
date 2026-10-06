#!/bin/bash
set -e

APP_NAME="Speuge"
VOL_NAME="Speuge"
FINAL_DMG="${APP_NAME}.dmg"
TMP_DMG="temp_installer.dmg"

# Clean up any leftover mounts
hdiutil detach "/Volumes/${VOL_NAME}" -force 2>/dev/null || true
sleep 1

echo "📦 Creating temporary writable disk image..."
rm -f "${TMP_DMG}" "${FINAL_DMG}"
hdiutil create -size 80m -fs HFS+ -volname "${VOL_NAME}" "${TMP_DMG}" -ov > /dev/null

echo "💿 Mounting temporary disk image..."
DEV_NAME=$(hdiutil attach "${TMP_DMG}" -noautoopen | grep -E "/Volumes/${VOL_NAME}" | awk '{print $1}')
MOUNT_DIR="/Volumes/${VOL_NAME}"
sleep 1

echo "📁 Copying ${APP_NAME}.app into installer image..."
cp -R "${APP_NAME}.app" "${MOUNT_DIR}/"

echo "🔗 Creating Applications drag-and-drop symlink..."
ln -s /Applications "${MOUNT_DIR}/Applications"

# Add background layout image (matches Finder's window size)
mkdir -p "${MOUNT_DIR}/.background"
if [ -f "AppResources/dmg_background.png" ]; then
    cp "AppResources/dmg_background.png" "${MOUNT_DIR}/.background/dmg_background.png"
fi
SetFile -a V "${MOUNT_DIR}/.background" 2>/dev/null || true

# Add custom volume icon if available
if [ -f "AppResources/AppIcon.icns" ]; then
    cp "AppResources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
    SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
fi

echo "🪄 Customizing Finder layout with transparent layout overlay..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        try
            set pathbar visible of container window to false
        end try
        try
            set sidebar width of container window to 0
        end try
        
        -- Exact 600 x 412 outer bounds gives exactly 600 x 380 content area (matching image size 600x380)
        set the bounds of container window to {350, 150, 950, 562}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to (POSIX file "${MOUNT_DIR}/.background/dmg_background.png" as alias)
        
        -- Position app icon on left, Applications on right over the logo holders
        set position of item "${APP_NAME}.app" of container window to {150, 205}
        set position of item "Applications" of container window to {450, 205}
        
        update without registering applications
        delay 1
        set the bounds of container window to {350, 150, 950, 562}
        delay 1
        close
    end tell
end tell
EOF

sync
sleep 1

# Hide background directory
SetFile -a V "${MOUNT_DIR}/.background" 2>/dev/null || true

echo "🔒 Unmounting installer disk image..."
hdiutil detach "${DEV_NAME}" -force > /dev/null 2>&1 || hdiutil detach "${MOUNT_DIR}" -force > /dev/null 2>&1 || true
sleep 2

echo "🗜️ Compressing into production installer DMG..."
hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG}" > /dev/null
rm -f "${TMP_DMG}"

echo "✅ Successfully built professional installer: ${FINAL_DMG}"
