//
//  ReadXRApp.swift
//  ReadXR
//
//  Created by Alex Kibler on 4/19/26.
//

import SwiftUI

@main
struct ReadXRApp: App {
    // Shared state for the entire app
    @State private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            ControllerView()
                .environment(appState)
                .onAppear {
                    // Trigger initial setup of background audio keep-alive
                    BackgroundAudioManager.shared.startBackgroundAudio()
                    BackgroundAudioManager.shared.updateNowPlaying()
                }
        }
    }
}
