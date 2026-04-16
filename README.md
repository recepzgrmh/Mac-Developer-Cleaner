<p align="center">
  <img src="assets/app_icon.png" width="128" height="128" alt="DevReclaim logo" />
</p>

# DevReclaim

**A native macOS disk cleaner for developers.**

DevReclaim helps you reclaim storage safely by cleaning developer junk such as **Xcode DerivedData**, **npm/yarn/pnpm caches**, **CocoaPods artifacts**, **Gradle caches**, and **Flutter/Dart build leftovers**.

If you searched for terms like **"macOS developer cleaner"**, **"Xcode cache cleaner"**, **"DerivedData cleaner"**, or **"delete npm cache on Mac"**, this app is built for exactly that workflow.

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-blue)](https://www.apple.com/macos)
[![Release](https://img.shields.io/github/v/release/recepzgrmh/Mac-Developer-Cleaner)](https://github.com/recepzgrmh/Mac-Developer-Cleaner/releases)

## Download

- Latest release: [Download from GitHub Releases](https://github.com/recepzgrmh/Mac-Developer-Cleaner/releases/latest)
- Current stable (v1.1.2): [DevReclaim v1.1.2](https://github.com/recepzgrmh/Mac-Developer-Cleaner/releases/tag/v1.1.2)

## Why DevReclaim

Most cleaner apps are generic, heavy, and risky. DevReclaim is intentionally focused on developer environments.

- Native SwiftUI app (no Electron/WebView overhead)
- Lightweight footprint
- Safety-first cleanup flow
- Built specifically for dev tools and build systems
- Clear audit/history of reclaimed space

## Key Features

- Smart scanning for developer-specific reclaim targets
- Preset-based cleanup for common ecosystems
- Dashboard-style overview for reclaimable space
- Execution history with audit-friendly logs
- Native-first cleanup with fallback flows

## Safety Model

- `.git` boundaries are respected
- No silent destructive actions
- Risk-aware cleanup behavior
- Explicit user intent before irreversible operations

## What It Can Clean

- Xcode: DerivedData, archives, logs
- JavaScript: npm cache, Yarn cache, pnpm store
- Apple/mobile: CocoaPods artifacts, Flutter/Dart cache
- Android/JVM: Gradle cache artifacts
- General developer cache leftovers

## Quick Start (User)

1. Open the latest `.dmg` from Releases.
2. Drag **DevReclaim.app** into **Applications**.
3. Launch DevReclaim and run a scan.
4. Review findings and apply cleanup safely.

## Build From Source

Requirements:

- macOS 14+
- Xcode 15+
- Swift 5.9+

Steps:

1. Clone the repository.
2. Open `Package.swift` in Xcode.
3. Select **My Mac**.
4. Build and run with `Cmd + R`.

## Package a DMG

```bash
bash scripts/package.sh 1.1.2
```

This creates a distributable DMG under `dist/`.

## Project Structure

- `DevReclaim/Core/Engine`: scanning and core logic
- `DevReclaim/Core/Executors`: cleanup execution paths
- `DevReclaim/UI/ViewModels`: state and presentation logic
- `DevReclaim/UI/Views`: SwiftUI screens/components
- `DevReclaim/Models`: domain models

## Contributing

Contributions are welcome.

1. Fork the repo
2. Create a feature branch
3. Commit your changes
4. Open a pull request

## License

MIT License.
