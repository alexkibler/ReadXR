import SwiftUI

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
