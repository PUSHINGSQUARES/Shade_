import XCTest
@testable import Shade_

final class CityDatabaseTests: XCTestCase {
    private let json = """
    [
      {"id":"bristol-uk","name":"Bristol","country":"UK","latitude":51.45,"longitude":-2.59},
      {"id":"london-uk","name":"London","country":"UK","latitude":51.5074,"longitude":-0.1278},
      {"id":"tokyo-jp","name":"Tokyo","country":"Japan","latitude":35.6762,"longitude":139.6503}
    ]
    """

    private func database() throws -> CityDatabase {
        try CityDatabase(data: Data(json.utf8))
    }

    func testLoadsAllCities() throws {
        XCTAssertEqual(try database().cities.count, 3)
    }

    func testSearchIsCaseInsensitiveSubstring() throws {
        let db = try database()
        XCTAssertEqual(db.search("lon").map(\.id), ["london-uk"])
        XCTAssertEqual(db.search("BRIS").map(\.id), ["bristol-uk"])
    }

    func testSearchEmptyQueryReturnsAll() throws {
        XCTAssertEqual(try database().search("").count, 3)
    }

    func testCityDisplayLabel() throws {
        let bristol = try XCTUnwrap(try database().cities.first { $0.id == "bristol-uk" })
        XCTAssertEqual(bristol.displayLabel, "Bristol, UK")
    }
}
