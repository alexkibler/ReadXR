ReadXR: Architecture & Implementation Spec
Project Overview
ReadXR is a specialized, local-only iOS ePub reader designed specifically for AR glasses. The app utilizes a dual-scene architecture:
The External Display Scene (AR Glasses): Renders the ePub content with a pure #000000 background (to turn off OLED pixels) and light text.
The Application Scene (iPhone): Acts as a blind-touch trackpad for page navigation, and handles local ePub importing.
The app uses an active background audio session playing a silent loop to keep the external display scene alive when the iPhone screen is locked. It hijacks MPRemoteCommandCenter to map lock screen/Apple Watch media controls to page turns.
Core Components to Generate
1. Scene Management & Shared State (Swift 6)
AppState.swift: Must use the modern Swift 6 @Observable macro. This singleton manages the global state: the currently loaded ePub data, current chapter/page index, and triggers UI updates.


ExternalSceneDelegate.swift: Must conform to UIWindowSceneDelegate. Intercepts the UIWindowSceneSessionRoleExternalDisplayNonInteractive connection. It creates a UIWindow, sets ReaderView as the root view controller via UIHostingController, and explicitly injects the shared AppState into the ReaderView's environment so state changes on the phone update the glasses.


2. Audio & Background Keep-Alive
BackgroundAudioManager.swift:
Initializes AVAudioSession with category .playback and options .mixWithOthers.


Continuously loops a silent 60-second .wav file using AVAudioPlayer to prevent iOS from suspending the app when the screen locks.


Configures MPRemoteCommandCenter to override nextTrackCommand (page forward) and previousTrackCommand (page back) , broadcasting these intents safely to AppState.


Configures MPNowPlayingInfoCenter to display the current book title, author, and reading progress on the iOS Lock Screen.


3. User Interface (SwiftUI)
ControllerView.swift (iPhone App Scene):
A strictly .black UI to save iPhone battery.
Implements DragGesture and TapGesture covering the entire screen to act as a trackpad.
Triggers immediate UIImpactFeedbackGenerator(style:.light) on page turns and .heavy on menu toggles.


Includes an interface to trigger the iOS UIDocumentPickerViewController to import .epub files directly from the local Files app/iCloud Drive.
ReaderView.swift (External Display Scene):
Must force a strict .black background.
Uses a WKWebView wrapped in UIViewRepresentable to render the ePub HTML/CSS chapters.
Injects CSS on load to force the background-color: #000000!important; and color: #E0E0E0; to ensure OLED pixels are turned off in the AR glasses.
Needs adjustable padding constraints to keep text out of the distorted edges of the AR lenses.
Fallback Routing: If no external display is connected, the iPhone scene should render a basic version of ReaderView so the app can be debugged without wearing the glasses.
4. Local Data Pipeline
EpubManager.swift:
Use the open-source Swift Package EPUBKit (https://github.com/witekbobrowski/EPUBKit.git) to parse the imported .epub files.


Extract the spine (reading order), manifest (HTML content), and Dublin Core metadata (Title, Author).


Extract the cover image to pass to the BackgroundAudioManager for the lock screen widget.
Persist the user's reading progress (current chapter/percentage) locally using UserDefaults or SwiftData.
Implementation Rules
Ensure all code complies with Swift 6 Strict Concurrency.


Do not modify project.pbxproj directly. Generate the .swift files and instruct the user to drag them into the Xcode project navigator.
Keep logic decoupled. The trackpad gestures on the iPhone must route through the shared @Observable state to update the ReaderView on the external display.

