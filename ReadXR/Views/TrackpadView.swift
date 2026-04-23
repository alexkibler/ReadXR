import SwiftUI

struct TrackpadView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = TrackpadViewModel()
    
    @Binding var showingChapters: Bool
    @Binding var showingReadingOptions: Bool
    @Binding var showingHighlights: Bool
    @Binding var showingSettings: Bool
    
    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                viewModel.handleDragEnded(value: value)
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                viewModel.handleLongPressEnded()
            }
    }

    var body: some View {
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

                VStack(spacing: 6) {
                    if let title = appState.currentChapterTitle {
                        Text("Ch \(appState.currentChapterIndex + 1) of \(appState.totalChapters)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.35))
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 16)
                    } else {
                        Text("Chapter \(appState.currentChapterIndex + 1) of \(appState.totalChapters)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Text("\(Int(appState.currentScrollPercentage * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.25))
                }

                Spacer()
            }

            if appState.returnChapterIndex != nil {
                Button(action: {
                    if let chIdx = appState.returnChapterIndex {
                        let isSameChapter = chIdx == appState.currentChapterIndex
                        let sid = appState.returnSentenceId
                        let scrollPct = appState.returnScrollPercentage
                        
                        appState.returnChapterIndex = nil
                        appState.returnSentenceId = nil
                        appState.returnScrollPercentage = nil
                        
                        appState.currentChapterIndex = chIdx
                        if let targetSid = sid {
                            if isSameChapter {
                                NotificationCenter.default.post(name: .scrollToHighlight, object: nil, userInfo: ["sentenceId": targetSid])
                            } else {
                                appState.pendingHighlightSentenceId = targetSid
                                EpubManager.shared.loadCurrentChapter()
                                EpubManager.shared.saveProgress()
                            }
                        } else if let targetPct = scrollPct {
                            if isSameChapter {
                                NotificationCenter.default.post(name: .scrollToPercentage, object: nil, userInfo: ["percentage": targetPct])
                            } else {
                                appState.currentScrollPercentage = targetPct
                                EpubManager.shared.loadCurrentChapter()
                                EpubManager.shared.saveProgress()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
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
            
            NavBarView(
                showingChapters: $showingChapters,
                showingReadingOptions: $showingReadingOptions,
                showingHighlights: $showingHighlights,
                showingSettings: $showingSettings
            )
                .foregroundColor(.white)
                .environment(\.colorScheme, .dark)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }
}

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
