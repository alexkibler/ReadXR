# ReadXR: Project Context & Implementation Guide

## Project Overview
ReadXR is a specialized, local-only iOS ePub reader designed specifically for AR glasses (e.g., XREAL, Viture). It uses a dual-scene architecture to maximize battery life and provide a tactile, eyes-off navigation experience.

### Main Technologies & Architecture
- **Language**: Swift 6 (Strict Concurrency enabled).
- **UI Framework**: SwiftUI for the iPhone interface and `WKWebView` wrapped in `UIViewRepresentable` for the AR display.
- **State Management**: Modern Swift 6 `@Observable` macro via `AppState.shared`.
- **ePub Parsing**: `EPUBKit` Swift Package.
- **Background Keep-Alive**: Active `AVAudioSession` playing a silent loop (`silence.wav`) to prevent app suspension when the iPhone screen is locked.

### Core Components
1. **Scene Management**:
   - `ExternalSceneDelegate.swift`: Intercepts `UIWindowSceneSessionRoleExternalDisplayNonInteractive` to render the reader onto external displays.
2. **State & Logic**:
   - `AppState.swift`: Singleton managing book metadata, current chapter content, and navigation intents.
   - `EpubManager.swift`: Handles file importing via `.fileImporter` and parses content into HTML.
3. **User Interface**:
   - `ControllerView.swift`: A black-background "blind-touch" trackpad for the iPhone.
   - `ReaderView.swift`: The external display view with forced OLED-black CSS (`#000000` background).
4. **Hardware Interop**:
   - `BackgroundAudioManager.swift`: Maps lock screen/Apple Watch media controls (Next/Previous Track) to page turns.

## Building and Running
1. **Xcode Requirements**: Xcode 15.0+ (Swift 6 support).
2. **Dependencies**:
   - Add **EPUBKit** via Swift Package Manager: `https://github.com/witekbobrowski/EPUBKit.git`
3. **Required Files**:
   - Ensure `silence.wav` is added to the project target.
4. **Running**:
   - For physical testing: Connect AR glasses via USB-C.
   - For Simulator testing: Go to **I/O -> Displays -> External Display** to simulate glasses.

## Development Conventions
- **OLED Efficiency**: All UI elements on the iPhone and Reader must be `#000000` black where possible to turn off OLED pixels and save battery.
- **Decoupling**: All navigation intents must flow through `AppState.shared`. Do not link the `ControllerView` directly to the `ReaderView`.
- **HTML Sanitization**: When loading new chapters in `EpubManager`, strip the `<body>` tags and XML declarations to ensure clean injection into the `WKWebView` template in `ReaderView`.
- **Haptics**: Always trigger `UIImpactFeedbackGenerator(style: .light)` for page turns and `.heavy` for menu toggles on the iPhone trackpad.
