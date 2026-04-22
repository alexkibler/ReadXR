import Foundation

/// Represents a highlighted section of text
struct Highlight: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let bookId: String
    let text: String
    let chapterName: String
    let pageOrProgress: String
    var chapterIndex: Int?
    var scrollPercentage: Double?
    /// data-sid of the first sentence span in the highlight
    var sentenceStartId: Int?
    /// data-sid of the last sentence span in the highlight
    var sentenceEndId: Int?
}
