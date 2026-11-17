import XCTest
@testable import ReachNews

final class NewsStoreTests: XCTestCase {
    func testSearchAndSaveArePersistent() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let story = Article(id: "one", title: "A story about climate", category: "Environment", time: "now", sources: 3, image: "forest", imageCredit: "", summary: "summary", coverage: Coverage(left: 10, center: 80, right: 10), agreement: "agree", disagreement: "disagree", perspectives: [])
        let store = NewsStore(defaults: defaults, articles: [story])
        XCTAssertEqual(store.search("climate").count, 1)
        store.toggleSave(story)
        XCTAssertTrue(store.savedIDs.contains("one"))
        let reloaded = NewsStore(defaults: defaults, articles: [story])
        XCTAssertTrue(reloaded.savedArticles.contains(story))
    }
}

