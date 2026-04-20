//
//  ControllerView.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The view displayed on the iPhone screen.
/// Acts as a blind-touch trackpad for navigating the ePub content on the external display.
struct ControllerView: View {
    @State private var appState = AppState.shared
    @State private var isImporting: Bool = false
    
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        ZStack {
            // Strictly black background to save battery
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                if !appState.isBookLoaded {
                    // Empty state with import button
                    VStack(spacing: 30) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No Book Loaded")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Button(action: { isImporting = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Import ePub")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    // Connected/Loaded state with navigation feedback
                    VStack {
                        if !appState.isExternalDisplayConnected {
                            Text("Debug Mode: Reading on iPhone")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .padding(.top, 10)
                            
                            ReaderView()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .padding()
                        } else {
                            Text("AR Glasses Connected")
                                .foregroundColor(.green)
                                .font(.caption)
                                .padding(.top, 10)
                        }
                        
                        Spacer()
                        
                        Text(appState.bookTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(appState.bookAuthor)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("Trackpad Active")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.title3)
                            .italic()
                        
                        Spacer()
                    }
                }
                
                // Trackpad Gesture Overlay (always active)
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard appState.isBookLoaded else { return }
                                    
                                    let horizontalSweep = value.translation.width
                                    let verticalSweep = value.translation.height
                                    
                                    if abs(horizontalSweep) < 10 && abs(verticalSweep) < 10 {
                                        // It's a Tap
                                        feedback.impactOccurred()
                                        appState.pageForward()
                                        print("Trackpad: Tap (Page Forward)")
                                    } else if horizontalSweep < -50 {
                                        // Swipe Left
                                        feedback.impactOccurred()
                                        appState.pageForward()
                                        print("Trackpad: Swipe Left (Page Forward)")
                                    } else if horizontalSweep > 50 {
                                        // Swipe Right
                                        feedback.impactOccurred()
                                        appState.pageBackward()
                                        print("Trackpad: Swipe Right (Page Backward)")
                                    } else if verticalSweep < -50 {
                                        // Swipe Up
                                        heavyFeedback.impactOccurred()
                                        appState.toggleMenu()
                                        print("Trackpad: Swipe Up (Menu)")
                                    }
                                }
                        )
                    
                    // Visual guide for the trackpad area
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .padding(40)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            checkExternalDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)) { _ in
            checkExternalDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)) { _ in
            checkExternalDisplay()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "epub")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                EpubManager.shared.handlePickedURL(url)
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fallback check for external displays (useful in Simulator)
    private func checkExternalDisplay() {
        let screens = UIScreen.screens
        print("Checking Screens. Count: \(screens.count)")
        if screens.count > 1 {
            appState.isExternalDisplayConnected = true
        } else {
            // Keep existing state if set by SceneDelegate
        }
    }
}

#Preview {
    ControllerView()
}
