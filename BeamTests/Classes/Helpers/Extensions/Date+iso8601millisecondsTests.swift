//
//  Date+iso8601millisecondsTests.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 11/03/2022.
//

import XCTest
import BeamCore
@testable import Beam

class Date_iso8601millisecondsTests: XCTestCase {

    func testDateWithMillisecondsWithTZ() {
        let dateAsString: String = "2022-03-08T14:42:15.082+01:00"
        let date = dateAsString.iso8601withFractionalSeconds
        XCTAssertEqual(date?.iso8601withFractionalSeconds, "2022-03-08T13:42:15.082Z")
    }

    func testDateWithMillisecondsWithoutTZ() {
        let dateAsString: String = "2022-03-08T13:42:15.082Z"
        let date = dateAsString.iso8601withFractionalSeconds
        XCTAssertEqual(date?.iso8601withFractionalSeconds, "2022-03-08T13:42:15.082Z")
    }
    
    func testEncodeDecodeJSON() throws {
        struct SampleData: Codable {
            let createdAt: Date?
            let id: String
            let count: Int
        }
        
        let sampleData = SampleData(
            createdAt: "2022-03-03T10:36:41.961+01:00".iso8601withFractionalSeconds,
            id: "sample_id",
            count: 42)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds
        let jsonData = try encoder.encode(sampleData)
        
        let decoder = BeamJSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        let decodedData = try decoder.decode(SampleData.self, from: jsonData)
        XCTAssertEqual(decodedData.createdAt, "2022-03-03T10:36:41.961+01:00".iso8601withFractionalSeconds)
        XCTAssertEqual(decodedData.id, "sample_id")
        XCTAssertEqual(decodedData.count, 42)
    }
}
