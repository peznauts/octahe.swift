import XCTest
@testable import swift_osi

final class swift_osiTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(swift_osi().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
