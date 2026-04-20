//
//  AppState.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

/// Represents a recently opened book
struct RecentBook: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let title: String
    let author: String
    let bookmarkData: Data
    var isFinished: Bool?
}

/// A singleton that manages the global state of the ReadXR app.
/// This includes the loaded ePub data, current reading progress, and navigation triggers.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()
    
    // MARK: - App State
    
    /// The currently loaded book title (from metadata)
    var bookTitle: String = "No Book Loaded"
    
    /// The currently loaded book author
    var bookAuthor: String = "Unknown Author"
    
    /// The current chapter/spine index
    var currentChapterIndex: Int = 0
    
    /// The current page index within the chapter (if applicable/tracked)
    var currentPageIndex: Int = 0
    
    /// Total chapters in the book
    var totalChapters: Int = 0
    
    /// The current scroll percentage (0.0 to 1.0) within the chapter
    var currentScrollPercentage: Double = 0.0
    
    /// The HTML content of the current chapter to be rendered in ReaderView
    var currentChapterHTML: String = ""
    
    /// The base URL for the current ePub content (unzipped location)
    var baseURL: URL? = nil
    
    /// Indicates if a book is currently loaded
    var isBookLoaded: Bool = false
    
    /// Indicates if an external display is currently connected and active
    var isExternalDisplayConnected: Bool = false
    
    /// List of recently loaded books
    var recentBooks: [RecentBook] = []
    
    // MARK: - Reading Options
    
    var fontSize: Double = 1.3
    var fontColor: String = "#E0E0E0"
    var margin: Double = 0.05
    var topBottomMargin: Double = 0.05
    var textJustify: String = "left"
    
    // MARK: - Navigation Intents
    
    /// Triggers a page forward navigation
    func pageForward() {
        NotificationCenter.default.post(name: .trackpadPageForward, object: nil)
        print("Intent: Page Forward")
    }
    
    /// Triggers a page backward navigation
    func pageBackward() {
        NotificationCenter.default.post(name: .trackpadPageBackward, object: nil)
        print("Intent: Page Backward")
    }
    
    /// Triggers a menu toggle
    func toggleMenu() {
        // Logic to toggle menu overlay (e.g., showing the document picker)
        EpubManager.shared.showDocumentPicker()
        print("Intent: Toggle Menu")
    }
    
    // MARK: - Actions
    
    /// Closes the current book and returns to the library UI
    func closeBook() {
        isBookLoaded = false
        bookTitle = "No Book Loaded"
        bookAuthor = "Unknown Author"
        currentChapterIndex = 0
        currentChapterHTML = ""
    }
    
    // MARK: - Private Initializer
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "recentBooks"),
           let recents = try? JSONDecoder().decode([RecentBook].self, from: data) {
            self.recentBooks = recents
        }
    }
    
    func saveRecents() {
        if let data = try? JSONEncoder().encode(recentBooks) {
            UserDefaults.standard.set(data, forKey: "recentBooks")
        }
    }
    
    func toggleBookFinished(_ book: RecentBook) {
        if let index = recentBooks.firstIndex(where: { $0.id == book.id }) {
            let current = recentBooks[index].isFinished ?? false
            recentBooks[index].isFinished = !current
            saveRecents()
        }
    }
    
    func deleteBook(_ book: RecentBook) {
        recentBooks.removeAll { $0.id == book.id }
        saveRecents()
    }
}

extension Notification.Name {
    static let trackpadPageForward = Notification.Name("trackpadPageForward")
    static let trackpadPageBackward = Notification.Name("trackpadPageBackward")
}
