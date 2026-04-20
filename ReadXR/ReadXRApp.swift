//
//  ReadXRApp.swift
//  ReadXR
//
//  Created by Alex Kibler on 4/19/26.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        
        print("🔴 APP DELEGATE CONFIGURING SCENE:")
        print("   - Role: \(connectingSceneSession.role.rawValue)")
        
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            print("   - MATCHED EXTERN DISPLAY NON-INTERACTIVE!")
            let config = UISceneConfiguration(name: "External Display", sessionRole: connectingSceneSession.role)
            config.delegateClass = ExternalSceneDelegate.self
            return config
        }
        
        print("   - RETURNING DEFAULT CONFIGURATION")
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        return config
    }
}

@main
struct ReadXRApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
