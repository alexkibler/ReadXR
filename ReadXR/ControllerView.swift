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
    @State private var didLongPress = false

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

    // MARK: - Navigation gesture (shared by both modes)

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard appState.isBookLoaded else { return }
                
                if didLongPress {
                    didLongPress = false
                    return
                }
                
                let h = value.translation.width
                let v = value.translation.height
                
                if appState.isHighlightMode {
                    if abs(h) < 10 && abs(v) < 10 {
                        feedback.impactOccurred()
                        NotificationCenter.default.post(name: .trackpadHighlightSave, object: nil)
                    } else if abs(v) > abs(h) {
                        if v > 30 {
                            feedback.impactOccurred()
                            let vel = abs(value.predictedEndTranslation.height - value.translation.height)
                            NotificationCenter.default.post(name: .trackpadHighlightMoveForward, object: nil, userInfo: ["velocity": vel])
                        } else if v < -30 {
                            feedback.impactOccurred()
                            let vel = abs(value.predictedEndTranslation.height - value.translation.height)
                            NotificationCenter.default.post(name: .trackpadHighlightMoveBackward, object: nil, userInfo: ["velocity": vel])
                        }
                    } else {
                        if h > 30 {
                            heavyFeedback.impactOccurred()
                            NotificationCenter.default.post(name: .trackpadHighlightExpandDown, object: nil)
                        } else if h < -30 {
                            heavyFeedback.impactOccurred()
                            NotificationCenter.default.post(name: .trackpadHighlightExpandUp, object: nil)
                        }
                    }
                } else {
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
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                guard appState.isBookLoaded else { return }
                didLongPress = true
                heavyFeedback.impactOccurred()
                if appState.isHighlightMode {
                    appState.isHighlightMode = false
                    NotificationCenter.default.post(name: .trackpadHighlightClear, object: nil)
                } else {
                    appState.isHighlightMode = true
                    NotificationCenter.default.post(name: .trackpadHighlightStart, object: nil)
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
                .simultaneousGesture(longPressGesture)
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
                                    if book.isFinished == true {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .contextMenu {
                                Button {
                                    appState.toggleBookFinished(book)
                                } label: {
                                    Label(book.isFinished == true ? "Mark as Unfinished" : "Mark as Finished", systemImage: book.isFinished == true ? "xmark.circle" : "checkmark.circle")
                                }
                                
                                Button(role: .destructive) {
                                    appState.deleteBook(book)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
                Color(white: 0.15)
                    .cornerRadius(20)
                
                DotPattern()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(navigationGesture)
                    .simultaneousGesture(longPressGesture)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            
            HStack {
                Button(action: { showingChapters = true }) {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { showingReadingOptions = true }) {
                    Image(systemName: "textformat.size")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { showingHighlights = true }) {
                    Image(systemName: "highlighter")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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

// MARK: - Subviews

struct DotPattern: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 2
            let spacing: CGFloat = 20
            
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.15)))
                }
            }
        }
    }
}

struct ChaptersView: View {
    let appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(0..<appState.totalChapters, id: \.self) { index in
                Button(action: {
                    EpubManager.shared.jumpToChapter(index)
                    dismiss()
                }) {
                    HStack {
                        Text("Chapter \(index + 1)")
                            .foregroundColor(.primary)
                        Spacer()
                        if appState.currentChapterIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
        }
    }
}

struct ReadingOptionsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Theme")) {
                    Picker("Color", selection: $appState.fontColor) {
                        Text("Light").tag("#E0E0E0")
                        Text("Sepia").tag("#F4ECD8")
                        Text("Dark").tag("#999999")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Text Size")) {
                    Stepper(String(format: "Size: %.1fx", appState.fontSize), value: $appState.fontSize, in: 0.8...3.0, step: 0.1)
                }
                
                Section(header: Text("Layout")) {
                    HStack {
                        Text("Side Margin")
                        Slider(value: $appState.margin, in: 0.0...0.2)
                    }
                    HStack {
                        Text("Top/Bottom Margin")
                        Slider(value: $appState.topBottomMargin, in: 0.0...0.2)
                    }
                    Picker("Alignment", selection: $appState.textJustify) {
                        Text("Left").tag("left")
                        Text("Justify").tag("justify")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Reading Options")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
            .onChange(of: appState.fontSize) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.fontColor) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.margin) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.topBottomMargin) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.textJustify) { EpubManager.shared.saveProgress() }
        }
    }
}

struct SettingsView: View {
    let appState: AppState
    @Binding var showingSettings: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Button("Return to Library") {
                    appState.closeBook()
                    showingSettings = false
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
        }
    }
}

struct HighlightsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if appState.activeBookHighlights.isEmpty {
                    Text("No highlights yet.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(appState.activeBookHighlights) { highlight in
                        Button(action: {
                            if let chIdx = highlight.chapterIndex, let scrollPct = highlight.scrollPercentage {
                                appState.currentChapterIndex = chIdx
                                appState.currentScrollPercentage = scrollPct
                                EpubManager.shared.loadCurrentChapter()
                                EpubManager.shared.saveProgress()
                                dismiss()
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(highlight.chapterName)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(highlight.pageOrProgress)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Text(highlight.text)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        let highlightsToDelete = indexSet.map { appState.activeBookHighlights[$0] }
                        for h in highlightsToDelete {
                            appState.highlights.removeAll { $0.id == h.id }
                        }
                        appState.saveHighlights()
                    }
                }
            }
            .navigationTitle("Highlights")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
        }
    }
}
