import SwiftUI

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
                            NotificationCenter.default.post(name: .captureTopSentenceAndNavigate, object: highlight)
                            dismiss()
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
