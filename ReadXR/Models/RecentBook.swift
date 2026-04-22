import Foundation

/// Represents a recently opened book
struct RecentBook: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let title: String
    let author: String
    let bookmarkData: Data
    var isFinished: Bool?
}
