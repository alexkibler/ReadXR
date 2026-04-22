//
//  AppState.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

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

    /// The display title of the current chapter (from NCX table of contents), if available
    var currentChapterTitle: String? = nil
    
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
    
    /// List of saved highlights
    var highlights: [Highlight] = []
    
    /// Indicates whether the user is currently actively selecting a highlight
    var isHighlightMode: Bool = false

    /// Saved chapter index to return to after navigating to a highlight
    var returnChapterIndex: Int? = nil

    /// Saved scroll percentage to return to after navigating to a highlight
    var returnScrollPercentage: Double? = nil

    /// Saved sentence ID to return to after navigating to a highlight
    var returnSentenceId: Int? = nil

    /// Sentence ID to scroll to after a chapter loads (set when navigating to a highlight)
    var pendingHighlightSentenceId: Int? = nil
    
    // MARK: - Audio Settings
    var lockScreenControls: Bool = StorageService.shared.loadLockScreenControlsPreference() {
        didSet { StorageService.shared.saveLockScreenControlsPreference(lockScreenControls) }
    }

    // MARK: - Reading Options (Internal)
    var fontSizeInternal: Double = 1.3
    var fontColorInternal: String = "#E0E0E0"
    var marginInternal: Double = 0.05
    var topBottomMarginInternal: Double = 0.05
    var textJustifyInternal: String = "left"

    // MARK: - Reading Options (External)
    var fontSizeExternal: Double = 1.3
    var fontColorExternal: String = "#E0E0E0"
    var marginExternal: Double = 0.05
    var topBottomMarginExternal: Double = 0.05
    var textJustifyExternal: String = "left"

    var fontSize: Double {
        get { isExternalDisplayConnected ? fontSizeExternal : fontSizeInternal }
        set { if isExternalDisplayConnected { fontSizeExternal = newValue } else { fontSizeInternal = newValue } }
    }
    var fontColor: String {
        get { isExternalDisplayConnected ? fontColorExternal : fontColorInternal }
        set { if isExternalDisplayConnected { fontColorExternal = newValue } else { fontColorInternal = newValue } }
    }
    var margin: Double {
        get { isExternalDisplayConnected ? marginExternal : marginInternal }
        set { if isExternalDisplayConnected { marginExternal = newValue } else { marginInternal = newValue } }
    }
    var topBottomMargin: Double {
        get { isExternalDisplayConnected ? topBottomMarginExternal : topBottomMarginInternal }
        set { if isExternalDisplayConnected { topBottomMarginExternal = newValue } else { topBottomMarginInternal = newValue } }
    }
    var textJustify: String {
        get { isExternalDisplayConnected ? textJustifyExternal : textJustifyInternal }
        set { if isExternalDisplayConnected { textJustifyExternal = newValue } else { textJustifyInternal = newValue } }
    }
    
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
    
    // MARK: - Highlights
    
    var activeBookHighlights: [Highlight] {
        let currentKey = "\(bookTitle)_\(bookAuthor)"
        return highlights.filter { $0.bookId == currentKey }
    }
    
    func saveCurrentHighlight(_ text: String, sentenceStartId: Int? = nil, sentenceEndId: Int? = nil) {
        let bookKey = "\(bookTitle)_\(bookAuthor)"
        let chapterName = "Chapter \(currentChapterIndex + 1)"
        let pageStr = "Page \(Int(currentScrollPercentage * 100))%"
        let newHL = Highlight(
            bookId: bookKey, text: text, chapterName: chapterName,
            pageOrProgress: pageStr, chapterIndex: currentChapterIndex,
            scrollPercentage: currentScrollPercentage,
            sentenceStartId: sentenceStartId, sentenceEndId: sentenceEndId
        )
        highlights.insert(newHL, at: 0)
        saveHighlights()
    }
    
    func saveHighlights() {
        StorageService.shared.saveHighlights(highlights)
    }
    
    // MARK: - Actions
    
    /// Closes the current book and returns to the library UI
    func closeBook() {
        isBookLoaded = false
        bookTitle = "No Book Loaded"
        bookAuthor = "Unknown Author"
        currentChapterIndex = 0
        currentChapterTitle = nil
        currentChapterHTML = ""
    }
    
    // MARK: - Private Initializer
    
    private init() {
        self.recentBooks = StorageService.shared.loadRecentBooks()
        self.highlights = StorageService.shared.loadHighlights()
    }
    
    func saveRecents() {
        StorageService.shared.saveRecentBooks(recentBooks)
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
    static let trackpadHighlightStart = Notification.Name("trackpadHighlightStart")
    static let trackpadHighlightClear = Notification.Name("trackpadHighlightClear")
    static let trackpadHighlightMoveForward = Notification.Name("trackpadHighlightMoveForward")
    static let trackpadHighlightMoveBackward = Notification.Name("trackpadHighlightMoveBackward")
    static let trackpadHighlightExpandDown = Notification.Name("trackpadHighlightExpandDown")
    static let trackpadHighlightExpandUp = Notification.Name("trackpadHighlightExpandUp")
    static let trackpadHighlightSave = Notification.Name("trackpadHighlightSave")
    static let scrollToHighlight = Notification.Name("scrollToHighlight")
    static let scrollToPercentage = Notification.Name("scrollToPercentage")
    static let captureTopSentenceAndNavigate = Notification.Name("captureTopSentenceAndNavigate")
}
