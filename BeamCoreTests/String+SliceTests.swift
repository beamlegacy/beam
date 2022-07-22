import XCTest

class StringSliceTests: XCTestCase {
    func testDropBefore() {
        XCTAssertEqual("https://www.redpanda.fr/foo/bar".dropBefore(substring: "www.redpanda.fr"), "www.redpanda.fr/foo/bar")
        XCTAssertEqual("https://www.redpanda.fr/foo/bar".dropBefore(substring: "https://www.redpanda.fr"), "https://www.redpanda.fr/foo/bar")
        XCTAssertEqual("https://www.redpanda.fr/foo/bar".dropBefore(substring: "bar"), "bar")
        XCTAssertNil("https://www.redpanda.fr/foo/bar".dropBefore(substring: ""))
        XCTAssertNil("https://www.redpanda.fr/foo/bar".dropBefore(substring: "baz"))
    }

    func testTruncated() {
        let longText = "The red panda, also known as the lesser panda, is a small mammal native to the eastern Himalayas and southwestern China."
        let ellipsis = "..."
        XCTAssertEqual(longText.truncated(limit: 13, position: .tail, leader: ellipsis), "The red panda"+ellipsis)
        XCTAssertEqual(longText.truncated(limit: 7, position: .tail, leader: ellipsis), "The red"+ellipsis)
        XCTAssertEqual(longText.truncated(limit: 19, position: .head, leader: ellipsis), ellipsis+"southwestern China.")
        XCTAssertEqual(longText.truncated(limit: 20, position: .middle, leader: ellipsis), "The red p"+ellipsis+"n China.")

        XCTAssertEqual("short".truncated(limit: 10, position: .tail, leader: ellipsis), "short")
        XCTAssertEqual("short".truncated(limit: 5, position: .tail, leader: ellipsis), "short")
    }
}
