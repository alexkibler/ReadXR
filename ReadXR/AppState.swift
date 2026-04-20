//
//  AppState.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import SwiftUI
import Observation

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
    
    /// The HTML content of the current chapter to be rendered in ReaderView
    var currentChapterHTML: String = ""
    
    /// The base URL for the current ePub content (unzipped location)
    var baseURL: URL? = nil
    
    /// Indicates if a book is currently loaded
    var isBookLoaded: Bool = false
    
    /// Indicates if an external display is currently connected and active
    var isExternalDisplayConnected: Bool = false
    
    // MARK: - Navigation Intents
    
    /// Triggers a page forward navigation
    func pageForward() {
        // For now, mapping page turns to chapter turns until sub-chapter paging is implemented
        EpubManager.shared.nextChapter()
        print("Intent: Page Forward")
    }
    
    /// Triggers a page backward navigation
    func pageBackward() {
        EpubManager.shared.previousChapter()
        print("Intent: Page Backward")
    }
    
    /// Triggers a menu toggle
    func toggleMenu() {
        // Logic to toggle menu overlay (e.g., showing the document picker)
        EpubManager.shared.showDocumentPicker()
        print("Intent: Toggle Menu")
    }
    
    // MARK: - Private Initializer
    
    private init() {}
}
