import Foundation

class PageInfo: Decodable {
    var endCursor: String?
    var hasNextPage: Bool
    var hasPreviousPage: Bool
    var startCursor: String?
}

class PaginatedBeamObjects: Decodable {
    var beamObjects: [BeamObject]?
    var pageInfo: PageInfo
}
