import XCTest
@testable import AgentNotch

final class RegressionTests: XCTestCase {
    @MainActor
    func testBehavioralRegressionSuite() async {
        let result = await AgentNotch.RegressionTests.run()
        XCTAssertEqual(result, 0)
    }
}
