import Foundation

struct BookProgress: Codable {
    let chapterIndex: Int
    let scrollPercentage: Double
    var fontSize: Double?
    var fontColor: String?
    var margin: Double?
    var topBottomMargin: Double?
    var textJustify: String?
    var fontSizeExternal: Double?
    var fontColorExternal: String?
    var marginExternal: Double?
    var topBottomMarginExternal: Double?
    var textJustifyExternal: String?
}
