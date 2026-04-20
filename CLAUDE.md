# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReadXR is an iOS ePub reader designed for AR glasses. It uses a dual-scene architecture: the iPhone acts as a blind-touch trackpad controller, while an external display (AR glasses) renders the book content with OLED-optimized styling (pure black background, light text).

## Building & Running

This is an Xcode project. Build and run via Xcode (open `ReadXR.xcodeproj`). There are no command-line build scripts.

**Important:** Do not modify `project.pbxproj` directly. When adding new `.swift` files, create them and instruct the user to drag them into the Xcode project navigator.

## Swift Package Dependencies

- **EPUBKit** (`https://github.com/witekbobrowski/EPUBKit.git`) — must be added via Xcode's SPM integration. Used in `EpubManager.swift` to parse `.epub` files.

## Architecture

All code must comply with **Swift 6 Strict Concurrency**. Core types are `@MainActor` singletons using the `@Observable` macro.

### State Flow

```
AppState.shared (@Observable singleton)
    ↑ writes                          ↓ reads
EpubManager.shared          ControllerView (iPhone)
BackgroundAudioManager.shared   ReaderView (External Display)
```

### Key Singletons

| Class | Role |
|-------|------|
| `AppState` | Central observable state: book metadata, chapter index, HTML content, display connection status |
| `EpubManager` | Parses EPUBs via EPUBKit, drives chapter navigation, presents `UIDocumentPickerViewController` |
| `BackgroundAudioManager` | Loops `silence.wav` (AVAudioPlayer) to keep app alive when screen locks; hijacks `MPRemoteCommandCenter` to map Next/Prev track → page turns; updates lock screen `MPNowPlayingInfoCenter` |

### Scene Architecture

The app declares `UIApplicationSupportsMultipleScenes = true` in `Info.plist`.

- **iPhone scene** → renders `ControllerView` (pure black trackpad UI + fallback `ReaderView` preview when no external display is connected)
- **External display scene** → handled by `ExternalSceneDelegate` (conforms to `UIWindowSceneDelegate`, role: `UIWindowSceneSessionRoleExternalDisplayNonInteractive`). Creates a `UIWindow`, sets `ReaderView` as root via `UIHostingController`, injects `AppState.shared` into environment.

### Views

- **`ControllerView`** (iPhone): Full-screen gesture overlay. Tap/swipe-left → `pageForward()`, swipe-right → `pageBackward()`, swipe-up → `toggleMenu()`. Light haptic on page turns, heavy haptic on menu. Uses `.fileImporter` for ePub import.
- **`ReaderView`** (External Display): Wraps `WKWebView` via `UIViewRepresentable` (`WebView`). Injects CSS to force `background-color: transparent`, `color: #E0E0E0`, disables scroll. Has configurable `horizontalPadding`/`verticalPadding` to avoid AR lens distortion edges.

### Navigation Intent Pattern

User gestures on iPhone call `AppState` intent methods (`pageForward`, `pageBackward`, `toggleMenu`), which delegate to `EpubManager` — keeping gesture handling decoupled from parsing logic.

### Background Keep-Alive

`silence.wav` must exist as either a Data Asset in `Assets.xcassets` (named `silence`) or as a bundle resource. `BackgroundAudioManager` checks both locations. The `UIBackgroundModes: audio` key is set in `Info.plist`.
