//
//  ControllerView.swift
//  ReadXR
//

import SwiftUI
import UniformTypeIdentifiers

struct ControllerView: View {
    @State private var appState = AppState.shared
    @State private var isImporting: Bool = false

    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        Group {
            if appState.isBookLoaded && !appState.isExternalDisplayConnected {
                fullScreenReader
            } else {
                trackpadUI
            }
        }
        .onAppear { checkExternalDisplay() }
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
            if case .success(let urls) = result, let url = urls.first {
                EpubManager.shared.handlePickedURL(url)
            }
        }
    }

    // MARK: - Navigation gesture (shared by both modes)

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard appState.isBookLoaded else { return }
                let h = value.translation.width
                let v = value.translation.height
                if abs(h) < 10 && abs(v) < 10 {
                    feedback.impactOccurred()
                    appState.pageForward()
                    print("Trackpad: Tap (Page Forward)")
                } else if h < -50 {
                    feedback.impactOccurred()
                    appState.pageForward()
                    print("Trackpad: Swipe Left (Page Forward)")
                } else if h > 50 {
                    feedback.impactOccurred()
                    appState.pageBackward()
                    print("Trackpad: Swipe Right (Page Backward)")
                } else if v < -50 {
                    heavyFeedback.impactOccurred()
                    appState.toggleMenu()
                    print("Trackpad: Swipe Up (Menu)")
                }
            }
    }

    // MARK: - Full-screen reader (phone-only mode)

    /// Shown when no external display is connected and a book is loaded.
    /// A transparent overlay captures gestures so the WebView doesn't need to handle navigation.
    private var fullScreenReader: some View {
        ZStack {
            ReaderView()
                .environment(AppState.shared)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(navigationGesture)
        }
    }

    // MARK: - Trackpad UI (AR glasses mode)

    private var trackpadUI: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                if !appState.isBookLoaded {
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
                    VStack {
                        Text("AR Glasses Connected")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 10)

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

                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(navigationGesture)

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .padding(40)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkExternalDisplay() {
        let screens = UIScreen.screens
        print("Checking Screens. Count: \(screens.count)")
        if screens.count > 1 {
            appState.isExternalDisplayConnected = true
        }
    }
}

#Preview {
    ControllerView()
}
