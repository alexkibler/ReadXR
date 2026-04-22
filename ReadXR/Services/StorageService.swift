import Foundation

/// A dedicated service for handling all UserDefaults persistence.
final class StorageService {
    static let shared = StorageService()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let recentBooks = "recentBooks"
        static let highlights = "highlights"
        static let lockScreenControls = "lockScreenControls"
        static func progressKey(title: String, author: String) -> String {
            return "progress_\(title)_\(author)"
        }
    }
    
    private init() {}
    
    // MARK: - Recent Books
    
    func loadRecentBooks() -> [RecentBook] {
        guard let data = defaults.data(forKey: Keys.recentBooks),
              let books = try? JSONDecoder().decode([RecentBook].self, from: data) else {
            return []
        }
        return books
    }
    
    func saveRecentBooks(_ books: [RecentBook]) {
        if let data = try? JSONEncoder().encode(books) {
            defaults.set(data, forKey: Keys.recentBooks)
        }
    }
    
    // MARK: - Highlights
    
    func loadHighlights() -> [Highlight] {
        guard let data = defaults.data(forKey: Keys.highlights),
              let highlights = try? JSONDecoder().decode([Highlight].self, from: data) else {
            return []
        }
        return highlights
    }
    
    func saveHighlights(_ highlights: [Highlight]) {
        if let data = try? JSONEncoder().encode(highlights) {
            defaults.set(data, forKey: Keys.highlights)
        }
    }
    
    // MARK: - Book Progress
    
    func loadProgress(title: String, author: String) -> BookProgress? {
        let key = Keys.progressKey(title: title, author: author)
        guard let data = defaults.data(forKey: key),
              let progress = try? JSONDecoder().decode(BookProgress.self, from: data) else {
            return nil
        }
        return progress
    }
    
    func saveProgress(_ progress: BookProgress, title: String, author: String) {
        let key = Keys.progressKey(title: title, author: author)
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key)
        }
    }
    
    // MARK: - Settings
    
    func loadLockScreenControlsPreference() -> Bool {
        return defaults.object(forKey: Keys.lockScreenControls) as? Bool ?? true
    }
    
    func saveLockScreenControlsPreference(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.lockScreenControls)
    }
}
