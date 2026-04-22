//
//  EpubManager.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import Foundation
import SwiftUI
import EPUBKit
import UniformTypeIdentifiers

/// Handles importing and parsing of .epub files.
/// Requires the EPUBKit package to be added to the project.
@MainActor
final class EpubManager: NSObject, UIDocumentPickerDelegate {
    static let shared = EpubManager()
    
    private let appState = AppState.shared
    private var currentDocument: EPUBDocument?
    
    private override init() {
        super.init()
    }
    
    /// Triggers the system document picker to select an .epub file.
    func showDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "epub")!])
        picker.delegate = self
        
        // Present the picker from the top-most view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(picker, animated: true)
        }
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        handlePickedURL(url)
    }
    
    /// Public method to handle URLs from SwiftUI .fileImporter or UIKit picker
    func handlePickedURL(_ url: URL) {
        // Ensure access to the local file (required for files outside the app sandbox)
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access document at: \(url)")
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        loadEpub(from: url)
    }
    
    /// Loads and parses the .epub file using EPUBKit.
    private func loadEpub(from url: URL) {
        guard let document = EPUBDocument(url: url) else {
            print("Failed to parse EPUB at: \(url)")
            return
        }
        
        self.currentDocument = document

        // Update global state
        appState.bookTitle = document.title ?? "Unknown Title"
        appState.bookAuthor = document.author ?? "Unknown Author"
        appState.totalChapters = document.spine.items.count
        
        let bookmarkData = try? url.bookmarkData()
        if let data = bookmarkData {
            let recent = RecentBook(id: UUID(), title: appState.bookTitle, author: appState.bookAuthor, bookmarkData: data)
            appState.recentBooks.removeAll { $0.title == recent.title && $0.author == recent.author }
            appState.recentBooks.insert(recent, at: 0)
            if appState.recentBooks.count > 10 {
                appState.recentBooks = Array(appState.recentBooks.prefix(10))
            }
            appState.saveRecents()
        }
        
        if let progress = StorageService.shared.loadProgress(title: appState.bookTitle, author: appState.bookAuthor) {
            appState.currentChapterIndex = min(progress.chapterIndex, appState.totalChapters - 1)
            appState.currentScrollPercentage = progress.scrollPercentage
            if let fs = progress.fontSize { appState.fontSizeInternal = fs }
            if let fc = progress.fontColor { appState.fontColorInternal = fc }
            if let m = progress.margin { appState.marginInternal = m }
            if let tbm = progress.topBottomMargin { appState.topBottomMarginInternal = tbm }
            if let tj = progress.textJustify { appState.textJustifyInternal = tj }
            
            if let fse = progress.fontSizeExternal { appState.fontSizeExternal = fse }
            if let fce = progress.fontColorExternal { appState.fontColorExternal = fce }
            if let me = progress.marginExternal { appState.marginExternal = me }
            if let tbme = progress.topBottomMarginExternal { appState.topBottomMarginExternal = tbme }
            if let tje = progress.textJustifyExternal { appState.textJustifyExternal = tje }
            print("Restoring progress: Chapter \(progress.chapterIndex), \(Int(progress.scrollPercentage * 100))%")
        } else {
            appState.currentChapterIndex = 0
            appState.currentScrollPercentage = 0.0
        }
        
        appState.baseURL = document.contentDirectory
        appState.isBookLoaded = true

        print("EPUB Loaded successfully. Content Directory: \(document.contentDirectory.path)")

        // Load the first chapter
        loadCurrentChapter()
        // Update lock screen metadata
        BackgroundAudioManager.shared.updateNowPlaying()
        
        print("Successfully loaded: \(appState.bookTitle)")
    }
    
    /// Extracts the HTML content of the current chapter from the spine.
    func loadCurrentChapter() {
        guard let document = currentDocument,
              appState.currentChapterIndex < document.spine.items.count else { return }
        
        let spineItem = document.spine.items[appState.currentChapterIndex]
        
        // Resolve the manifest item via the idref
        guard let manifestItem = document.manifest.items[spineItem.idref] else {
            appState.currentChapterHTML = "<p style='color:red;'>Spine item not found in manifest.</p>"
            return
        }
        
        // EPUBKit uses .path for the full relative path within the EPUB
        let chapterURL = document.contentDirectory.appendingPathComponent(manifestItem.path)

        // Update baseURL to the folder containing this chapter (for local image/CSS resolution)
        appState.baseURL = chapterURL.deletingLastPathComponent()

        // Resolve chapter title from the NCX table of contents
        appState.currentChapterTitle = tocLabel(for: manifestItem.path, in: document.tableOfContents)
        
        if var htmlString = try? String(contentsOf: chapterURL, encoding: .utf8) {
            // Extract only the content INSIDE the body tags
            if let bodyStartRange = htmlString.range(of: "<body", options: .caseInsensitive),
               let startCloseRange = htmlString[bodyStartRange.upperBound...].range(of: ">") {
                let afterBodyTag = htmlString[startCloseRange.upperBound...]
                if let bodyEndRange = afterBodyTag.range(of: "</body>", options: .caseInsensitive) {
                    htmlString = String(afterBodyTag[..<bodyEndRange.lowerBound])
                } else {
                    htmlString = String(afterBodyTag)
                }
            }
            
            appState.currentChapterHTML = htmlString
            print("Successfully loaded chapter index \(appState.currentChapterIndex). Cleaned Length: \(htmlString.count)")
            print("Content Preview: \(htmlString.prefix(50))")
        } else {
            // If .path didn't work, try using the directory path + the manifest path
            appState.currentChapterHTML = "<p style='color:red;'>Failed to read file at: \(manifestItem.path)</p>"
            print("Error: Could not read HTML file at \(chapterURL.path)")
        }
    }
    
    /// Navigates to the next chapter.
    func nextChapter() {
        if appState.currentChapterIndex < appState.totalChapters - 1 {
            appState.currentChapterIndex += 1
            appState.currentScrollPercentage = 0.0
            loadCurrentChapter()
            saveProgress()
            BackgroundAudioManager.shared.updateNowPlaying()
        }
    }
    
    /// Navigates to the previous chapter.
    func previousChapter() {
        if appState.currentChapterIndex > 0 {
            appState.currentChapterIndex -= 1
            appState.currentScrollPercentage = 1.0
            loadCurrentChapter()
            saveProgress()
            BackgroundAudioManager.shared.updateNowPlaying()
        }
    }
    
    /// Navigates to a specific chapter index
    func jumpToChapter(_ index: Int) {
        if index >= 0 && index < appState.totalChapters {
            appState.currentChapterIndex = index
            appState.currentScrollPercentage = 0.0
            loadCurrentChapter()
            saveProgress()
            BackgroundAudioManager.shared.updateNowPlaying()
        }
    }

    /// Saves the current reading progress to UserDefaults.
    func saveProgress() {
        let progress = BookProgress(
            chapterIndex: appState.currentChapterIndex,
            scrollPercentage: appState.currentScrollPercentage,
            fontSize: appState.fontSizeInternal,
            fontColor: appState.fontColorInternal,
            margin: appState.marginInternal,
            topBottomMargin: appState.topBottomMarginInternal,
            textJustify: appState.textJustifyInternal,
            fontSizeExternal: appState.fontSizeExternal,
            fontColorExternal: appState.fontColorExternal,
            marginExternal: appState.marginExternal,
            topBottomMarginExternal: appState.topBottomMarginExternal,
            textJustifyExternal: appState.textJustifyExternal
        )
        StorageService.shared.saveProgress(progress, title: appState.bookTitle, author: appState.bookAuthor)
    }
    
    // MARK: - TOC helpers

    /// Searches the NCX table of contents tree for a label matching the given manifest path.
    /// Matches by comparing the TOC href (stripped of any fragment) against the manifest path's
    /// last path component, to handle varying directory prefixes across EPUB packages.
    private func tocLabel(for manifestPath: String, in toc: EPUBTableOfContents) -> String? {
        let filename = (manifestPath as NSString).lastPathComponent
        func search(_ node: EPUBTableOfContents) -> String? {
            if let href = node.item {
                let hrefPath = href.components(separatedBy: "#").first ?? href
                let hrefFilename = (hrefPath as NSString).lastPathComponent
                if hrefFilename == filename && !node.label.trimmingCharacters(in: .whitespaces).isEmpty {
                    return node.label.trimmingCharacters(in: .whitespaces)
                }
            }
            for child in node.subTable ?? [] {
                if let found = search(child) { return found }
            }
            return nil
        }
        return search(toc)
    }

    /// Loads a previously opened book.
    func loadRecentBook(_ book: RecentBook) {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: book.bookmarkData, bookmarkDataIsStale: &isStale) else {
            print("Failed to resolve bookmark for \(book.title)")
            // Remove from recents if stale/invalid
            appState.recentBooks.removeAll { $0.id == book.id }
            appState.saveRecents()
            return
        }
        handlePickedURL(url)
    }
}
