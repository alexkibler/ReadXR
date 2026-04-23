import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Binding var isImporting: Bool
    
    var body: some View {
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
}
