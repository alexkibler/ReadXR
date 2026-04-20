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

            if !appState.isBookLoaded {
                noBookLoadedUI
            } else {
                activeTrackpadUI
            }
        }
    }

    private var noBookLoadedUI: some View {
        VStack(spacing: 20) {
            HStack {
                Text(appState.recentBooks.isEmpty ? "Welcome" : "Recent Books")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { isImporting = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.black)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            
            if appState.recentBooks.isEmpty {
                Spacer()
                Image(systemName: "book.pages")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))
                
                Text("No Books Yet")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Import an EPUB to start reading")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(appState.recentBooks) { book in
                            Button(action: {
                                EpubManager.shared.loadRecentBook(book)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(book.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text(book.author)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 10)
            }
        }
    }

    private var activeTrackpadUI: some View {
        VStack(spacing: 20) {
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
