//
//  ControllerView.swift
//  ReadXR
//

import SwiftUI
import UniformTypeIdentifiers

struct ControllerView: View {
    @State private var appState = AppState.shared
    @State private var isImporting: Bool = false
    @State private var showingChapters = false
    @State private var showingReadingOptions = false
    @State private var showingSettings = false
    @State private var showingHighlights = false

    var body: some View {
        Group {
            if appState.isBookLoaded && !appState.isExternalDisplayConnected {
                fullScreenReader
            } else {
                trackpadUI
            }
        }
        .onAppear { checkExternalDisplay() }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willConnectNotification)) { notification in
            if let scene = notification.object as? UIScene, scene.session.role == .windowExternalDisplayNonInteractive {
                appState.isExternalDisplayConnected = true
                // Only start background audio when AR glasses are connected
                BackgroundAudioManager.shared.startBackgroundAudio()
                BackgroundAudioManager.shared.updateNowPlaying()
            } else {
                checkExternalDisplay()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { notification in
            if let scene = notification.object as? UIScene, scene.session.role == .windowExternalDisplayNonInteractive {
                appState.isExternalDisplayConnected = false
            } else {
                checkExternalDisplay()
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "epub")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                EpubManager.shared.handlePickedURL(url)
            }
        }
        .sheet(isPresented: $showingChapters) {
            ChaptersView(appState: appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReadingOptions) {
            ReadingOptionsView(appState: appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    if appState.isBookLoaded {
                        EpubManager.shared.saveProgress()
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(appState: appState, showingSettings: $showingSettings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingHighlights) {
            HighlightsView(appState: appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Full-screen reader (phone-only mode)

    /// Shown when no external display is connected and a book is loaded.
    /// A transparent overlay captures gestures so the WebView doesn't need to handle navigation.
    private var fullScreenReader: some View {
        ZStack {
            ReaderView()
                .environment(AppState.shared)

            // No gesture overlay in iPhone mode: the WebView's native UIScrollView handles
            // paging and long-press text selection directly.

            // Float the nav bar at the bottom using VStack so it stays above the
            // home indicator without adding any inset to the WebView's coordinate space.
            VStack {
                Spacer()
                NavBarView(
                    showingChapters: $showingChapters,
                    showingReadingOptions: $showingReadingOptions,
                    showingHighlights: $showingHighlights,
                    showingSettings: $showingSettings
                )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Trackpad UI (AR glasses mode)

    private var trackpadUI: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if !appState.isBookLoaded {
                LibraryView(isImporting: $isImporting)
            } else {
                TrackpadView(
                    showingChapters: $showingChapters,
                    showingReadingOptions: $showingReadingOptions,
                    showingHighlights: $showingHighlights,
                    showingSettings: $showingSettings
                )
            }
        }
    }

    // MARK: - Helpers

    private func checkExternalDisplay() {
        let hasExternalDisplay = UIApplication.shared.connectedScenes.contains { $0.session.role == .windowExternalDisplayNonInteractive }
        print("Checking Scenes. External display active: \(hasExternalDisplay)")
        if hasExternalDisplay {
            appState.isExternalDisplayConnected = true
        } else {
            appState.isExternalDisplayConnected = false
        }
    }
}

#Preview {
    ControllerView()
}
