# Network Speed for macOS 🚀

A lightweight, native macOS menu bar application that displays real-time Download and Upload network speeds directly in your menu bar with dynamic auto-scaling units (**B/s**, **KB/s**, **MB/s**, **GB/s**, and **TB/s**).

Built natively using **Swift**, **AppKit**, and **SwiftUI** with zero external dependencies and near-zero CPU footprint.

---

## 🔒 Privacy & Security First

- **100% Offline & Private**: Zero telemetry, zero analytics, and zero external tracking.
- **No Internet Permissions Required**: Reads purely local kernel routing counters (`NET_RT_IFLIST2` via `sysctl`).
- **Native & Lightweight**: Pure native Swift without Electron, Chromium, or Node.js.
- **Open Source**: Transparent codebase with zero third-party dependencies.

---

## ✨ Features

- **⚡ Real-Time Speeds in the Menu Bar**:
  - Live upload and download throughput sampled via Darwin kernel 64-bit routing statistics.
  - Dynamic auto-scaling units: `B/s` ➔ `KB/s` ➔ `MB/s` ➔ `GB/s` ➔ `TB/s`.
  - Monospaced digits (`.monospacedDigitSystemFont`) to eliminate jitter and text wobble.
  - Multiple display modes: Two lines stacked, single line inline, download only, or upload only.
  - Direction indicators: Triangles (`▲`/`▼`), arrows (`↑`/`↓`), or letters (`U:`/`D:`).
  - Native vibrancy with automatic light/dark mode support.

- **📊 Modern Dashboard (Left-Click)**:
  - **Live Speed Readouts**: Real-time upload and download speeds with peak metrics.
  - **Session Metrics**: Tracks total session upload and download volume.
  - **Live Activity Graph**: Hardware-accelerated 60-second dual sparkline canvas chart.
  - **Active Interface & IP Badge**: Displays active network adapter and local IP with one-click clipboard copy.

- **⚙️ User Preferences**:
  - **Display Styles**: Stacked (2-line), Inline (1-line), Download Only, Upload Only.
  - **Display Order**: Download first or Upload first.
  - **Update Frequency**: 0.5s (Fast), 1.0s (Normal), 2.0s (Eco).
  - **Calculation Standard**: Binary (1024) or Decimal (1000).
  - **Interface Selector**: Monitor all active interfaces combined or lock to a specific adapter.
  - **Launch at Login**: Native integration with macOS `SMAppService`.

- **🖱️ Quick Context Menu (Right-Click)**:
  - Fast access to Open Dashboard, Reset Session Stats, Change Display Style, Switch Refresh Rate, and Quit.

---

## 🚀 Installation & Usage

### Method 1: Download Pre-built Release (Recommended)

1. Download the latest **`NetworkSpeed.dmg`** from the [Releases](https://github.com/slkslh/network-speed/releases) page.
2. Open `NetworkSpeed.dmg` and drag **NetworkSpeed** into your **Applications** folder.
3. Launch **NetworkSpeed** from Applications or Spotlight.

> **Note on First Launch:** If macOS shows an unidentified developer warning, right-click (or Control-click) `NetworkSpeed.app` in `/Applications` and select **Open**, then click **Open** in the dialog.

---

### Method 2: Build from Source

#### Prerequisites
- macOS 13.0 (Ventura) or newer
- Xcode 14+ or Xcode Command Line Tools (`xcode-select --install`)

#### Build and Run
Clone this repository and run the build script:

```bash
git clone https://github.com/slkslh/network-speed.git
cd network-speed

# Build the Universal Binary, App bundle, ZIP, and DMG installer
./build_app.sh

# Or build and install directly to /Applications
./build_app.sh --install
```

You can also run directly with Swift Package Manager:
```bash
swift run -c release
```

---

## 🛠️ Project Structure

```
NetworkSpeed/
├── AppResources/
│   ├── AppIcon.icns                   # Multi-resolution Retina application icon
│   ├── dmg_background.png             # Drag-and-drop installer background artwork
│   └── Info.plist                     # Application bundle configuration (LSUIElement = true)
├── Sources/
│   └── NetworkSpeed/
│       ├── main.swift                 # Application entry point
│       ├── AppDelegate.swift          # StatusItem, floating panel & context menu
│       ├── Models/
│       │   ├── AppSettings.swift      # Persistent user preferences (UserDefaults)
│       │   ├── NetworkStats.swift     # Observable state, rolling history & metrics
│       │   └── SpeedFormatter.swift   # Dynamic B/s, KB/s, MB/s, GB/s unit formatting
│       ├── Services/
│       │   ├── LaunchAtLogin.swift    # macOS SMAppService login helper
│       │   └── NetworkMonitor.swift   # Low-overhead 64-bit kernel sysctl sampler
│       └── Views/
│           ├── LiveHistoryChart.swift # Canvas-based real-time activity sparkline
│           ├── MenuBarExtraPanel.swift# Custom floating glassmorphism panel
│           ├── MenuBarView.swift      # Status item view drawing menu bar text
│           └── PopoverView.swift      # SwiftUI dashboard and settings interface
├── build_app.sh                       # Universal release build & bundle script
├── package_dmg.sh                     # Disk image (DMG) creation script
├── Package.swift                      # Swift Package Manager manifest
├── .gitignore                         # Git exclusion rules
├── LICENSE                            # MIT License
└── README.md                          # Project documentation
```

---

## 📋 Requirements
- **macOS**: 13.0 (Ventura) or newer (macOS 14 Sonoma, macOS 15 Sequoia, and newer fully supported).
- **Architecture**: Universal (Apple Silicon `arm64` + Intel `x86_64`).

---

## 📄 License
This project is licensed under the [MIT License](LICENSE) — see the LICENSE file for details.
