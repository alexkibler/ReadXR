//
//  ExternalSceneDelegate.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import UIKit
import SwiftUI

/// Intercepts and manages the scene for the external display (AR glasses).
/// Role: UIWindowSceneSessionRoleExternalDisplayNonInteractive.
@MainActor
@objc(ExternalSceneDelegate)
final class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        // Ensure the scene is a UIWindowScene
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Verify this is indeed an external display scene
        print("🟢 EXTERNAL SCENE DELEGATE CALLED!")
        print("   - Scene: \(scene)")
        print("   - Role: \(session.role.rawValue)")
        
        guard session.role == .windowExternalDisplayNonInteractive else { 
            print("   - Ignoring connection: Incorrect role.")
            return 
        }
        
        print("   - Role test passed! Creating UIWindow...")
        
        // Create the window
        let window = UIWindow(windowScene: windowScene)
        
        // Initialize the ReaderView with the shared AppState
        let readerView = ReaderView()
            .environment(AppState.shared)
        
        // Create the UIHostingController
        let hostingController = UIHostingController(rootView: readerView)
        
        // Configure the window with the hosting controller
        window.rootViewController = hostingController
        
        // Ensure the background of the window and root view is strictly black
        window.backgroundColor = .red
        hostingController.view.backgroundColor = .red
        
        // Set and make the window visible
        self.window = window
        window.makeKeyAndVisible()
        
        // Inform AppState that the external display is now connected
        AppState.shared.isExternalDisplayConnected = true
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Handle external display disconnection
        AppState.shared.isExternalDisplayConnected = false
        self.window = nil
    }
}
