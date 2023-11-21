import XCTest
@testable import NabtoEdgeClient

final class NabtoEdgeClientTests: XCTestCase {
    func testVersionString() throws {
        let prefix = Client.versionString().prefix(2)
        let isBranch = prefix == "5."
        let isMaster = prefix == "0."
        XCTAssertTrue(isBranch || isMaster, "version prefix: \(prefix)")
    }
}
