import XCTest
@testable import ReadXR

@MainActor
final class AppStateTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Clear UserDefaults keys used by AppState to ensure a clean slate for each test
        UserDefaults.standard.removeObject(forKey: "recentBooks")
        UserDefaults.standard.removeObject(forKey: "highlights")
        UserDefaults.standard.removeObject(forKey: "lockScreenControls")
        
        // Reset the singleton state manually
        let appState = AppState.shared
        appState.closeBook()
        appState.recentBooks = []
        appState.highlights = []
        appState.isHighlightMode = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppStateDefaults() throws {
        let appState = AppState.shared
        
        XCTAssertEqual(appState.bookTitle, "No Book Loaded")
        XCTAssertEqual(appState.bookAuthor, "Unknown Author")
        XCTAssertEqual(appState.currentChapterIndex, 0)
        XCTAssertEqual(appState.currentScrollPercentage, 0.0)
        XCTAssertFalse(appState.isBookLoaded)
        XCTAssertTrue(appState.recentBooks.isEmpty)
        XCTAssertTrue(appState.highlights.isEmpty)
    }

    func testSavingRecentBook() throws {
        let appState = AppState.shared
        
        let dummyData = Data("dummy bookmark".utf8)
        let newBook = RecentBook(title: "Test Book", author: "Test Author", bookmarkData: dummyData, isFinished: false)
        
        appState.recentBooks.append(newBook)
        appState.saveRecents()
        
        // Simulate an app restart by reading from UserDefaults directly
        guard let savedData = UserDefaults.standard.data(forKey: "recentBooks") else {
            XCTFail("Recent books were not saved to UserDefaults")
            return
        }
        
        let decoder = JSONDecoder()
        let decodedBooks = try decoder.decode([RecentBook].self, from: savedData)
        
        XCTAssertEqual(decodedBooks.count, 1)
        XCTAssertEqual(decodedBooks.first?.title, "Test Book")
        XCTAssertEqual(decodedBooks.first?.author, "Test Author")
    }

    func testSavingHighlight() throws {
        let appState = AppState.shared
        
        // Setup mock book state
        appState.bookTitle = "Moby Dick"
        appState.bookAuthor = "Herman Melville"
        appState.currentChapterIndex = 5
        appState.currentScrollPercentage = 0.5
        
        appState.saveCurrentHighlight("Call me Ishmael.", sentenceStartId: 10, sentenceEndId: 12)
        
        XCTAssertEqual(appState.highlights.count, 1)
        let savedHighlight = appState.highlights.first
        XCTAssertEqual(savedHighlight?.text, "Call me Ishmael.")
        XCTAssertEqual(savedHighlight?.bookId, "Moby Dick_Herman Melville")
        XCTAssertEqual(savedHighlight?.chapterName, "Chapter 6") // currentChapterIndex is 0-based
        XCTAssertEqual(savedHighlight?.pageOrProgress, "Page 50%")
        XCTAssertEqual(savedHighlight?.sentenceStartId, 10)
        XCTAssertEqual(savedHighlight?.sentenceEndId, 12)
        
        // Verify UserDefaults persistence
        guard let savedData = UserDefaults.standard.data(forKey: "highlights") else {
            XCTFail("Highlights were not saved to UserDefaults")
            return
        }
        
        let decoder = JSONDecoder()
        let decodedHighlights = try decoder.decode([Highlight].self, from: savedData)
        XCTAssertEqual(decodedHighlights.count, 1)
        XCTAssertEqual(decodedHighlights.first?.text, "Call me Ishmael.")
    }
    
    func testCloseBookClearsState() throws {
        let appState = AppState.shared
        
        appState.isBookLoaded = true
        appState.bookTitle = "Test Book"
        appState.bookAuthor = "Test Author"
        appState.currentChapterIndex = 10
        appState.currentChapterTitle = "Chapter 11"
        appState.currentChapterHTML = "<p>Test</p>"
        
        appState.closeBook()
        
        XCTAssertFalse(appState.isBookLoaded)
        XCTAssertEqual(appState.bookTitle, "No Book Loaded")
        XCTAssertEqual(appState.bookAuthor, "Unknown Author")
        XCTAssertEqual(appState.currentChapterIndex, 0)
        XCTAssertNil(appState.currentChapterTitle)
        XCTAssertEqual(appState.currentChapterHTML, "")
    }
}
