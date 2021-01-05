import Foundation

protocol GraphqlParametersProtocol: Encodable {
    associatedtype T: Encodable
    var query: String? { get set }
    var fileName: String? { get set }
    var fragmentsFileName: [String]? { get set }
    var variables: T { get }
}

struct EmptyVariable: Encodable {}

struct GraphqlParameters<T: Encodable>: GraphqlParametersProtocol {
    var fileName: String?
    var fragmentsFileName: [String]?
    var query: String?
    var variables: T
}
