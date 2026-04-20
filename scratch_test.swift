import Foundation

struct BookProgress: Codable {
    let chapterIndex: Int
    let scrollPercentage: Double
    var fontSize: Double?
    var fontColor: String?
    var margin: Double?
    var topBottomMargin: Double?
    var textJustify: String?
}

let p = BookProgress(chapterIndex: 1, scrollPercentage: 0.5, fontSize: 2.0, fontColor: "#E0E0E0", margin: 0.05, topBottomMargin: 0.05, textJustify: "left")

if let data = try? JSONEncoder().encode(p) {
    if let str = String(data: data, encoding: .utf8) {
        print("ENCODED:", str)
    }
}
