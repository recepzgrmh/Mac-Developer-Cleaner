<p align="center">
  <img src="assets/app_icon.png" width="128" height="128" alt="Mac-Developer-Cleaner Logo">
</p>

# 🚀 Mac-Developer-Cleaner

**The lightweight, native macOS disk cleaner built specifically for developers.**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Most "Mac Cleaners" are bloated, slow, and don't understand developer workflows. **Mac-Developer-Cleaner** is different. It's built with pure SwiftUI, has zero dependencies, and understands the difference between a "cache" and your "source code."

---

## ✨ Key Features

- **🚀 Native Performance:** Built with SwiftUI. No Electron, no WebViews. Tiny footprint (<15MB).
- **🛡️ Safety First:** 
  - **.git Boundary:** Never scans or touches your repository source code.
  - **Native Cleanup:** Uses tools like `npm cache clean` or `flutter clean` when available.
  - **Trash Fallback:** If a command fails, it asks to move files to the Trash. Never deletes silently.
- **📦 Smart Presets:** Pre-configured paths for **npm, Xcode, CocoaPods, Gradle, Flutter, and more.**
- **📜 Audit Logs:** Keep track of every MB reclaimed in a local history log.

## 📸 Screenshots
*(Tip: Add your app screenshots here to get more stars!)*
<table>
  <tr>
    <td><img src="https://via.placeholder.com/400x250?text=Sidebar+Navigation" width="400"></td>
    <td><img src="https://via.placeholder.com/400x250?text=Scan+Results" width="400"></td>
  </tr>
</table>

## 🛠 Supported Presets
- **Xcode:** DerivedData, Archives, iOS Device Logs.
- **Package Managers:** npm cache, Yarn cache, pnpm store, CocoaPods.
- **Mobile/Web:** Flutter/Dart cache, Gradle user home.
- **System:** Homebrew leftovers, Caches.

## 🚀 Installation & Usage

### Option 1: Build from Source
1. Clone the repo: `git clone https://github.com/YOUR_USERNAME/DevReclaim.git`
2. Open `Package.swift` in Xcode 15+.
3. Build and Run (`Cmd + R`).

### Option 2: Release
Check the [Releases](https://github.com/YOUR_USERNAME/DevReclaim/releases) page for the latest `.dmg`.

## 🤝 Contributing
Contributions are welcome! If you have a preset for a tool we don't support yet, please open a PR.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.

---
*Built with ❤️ for the macOS Developer Community.*
