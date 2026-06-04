import XCTest
@testable import Vela

final class PersistenceFoundationTests: XCTestCase {
    func testModelContainerSchemaCreatedSuccessfully() {
        let schema = VelaModelContainer.schema
        XCTAssertNotNil(schema)
    }
}
