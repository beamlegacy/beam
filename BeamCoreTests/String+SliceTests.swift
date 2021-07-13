import XCTest

class StringSliceTests: XCTestCase {
    func testDropBefore() {
        XCTAssertEqual("https://www.lemonde.fr/foo/bar".dropBefore(substring: "www.lemonde.fr"), "www.lemonde.fr/foo/bar")
        XCTAssertEqual("https://www.lemonde.fr/foo/bar".dropBefore(substring: "https://www.lemonde.fr"), "https://www.lemonde.fr/foo/bar")
        XCTAssertEqual("https://www.lemonde.fr/foo/bar".dropBefore(substring: "bar"), "bar")
        XCTAssertNil("https://www.lemonde.fr/foo/bar".dropBefore(substring: ""))
        XCTAssertNil("https://www.lemonde.fr/foo/bar".dropBefore(substring: "baz"))
    }
}
