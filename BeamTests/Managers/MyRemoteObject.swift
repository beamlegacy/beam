import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

// Minimal object for the purpose of testing and storing during tests
struct MyRemoteObject: BeamObjectProtocol {
    static var beamObjectType = BeamObjectObjectType.myRemoteObject

    var beamObjectId = UUID()

    var createdAt = BeamDate.now
    var updatedAt = BeamDate.now
    var deletedAt: Date?

    var title: String?


    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
        case title
        case createdAt
        case updatedAt
        case deletedAt
    }
}

extension MyRemoteObject: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.beamObjectId == rhs.beamObjectId &&
            lhs.createdAt.intValue == rhs.createdAt.intValue &&
            lhs.updatedAt.intValue == rhs.updatedAt.intValue &&
            lhs.deletedAt?.intValue == rhs.deletedAt?.intValue &&
            lhs.title == rhs.title
    }
}

extension MyRemoteObject {
    func copy() -> MyRemoteObject {
        MyRemoteObject(beamObjectId: beamObjectId,
                       createdAt: createdAt,
                       updatedAt: updatedAt,
                       deletedAt: deletedAt,
                       title: title)
    }
}
