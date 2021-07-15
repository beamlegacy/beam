import Foundation

protocol GraphqlParametersProtocol: Encodable {
    associatedtype GenericType: Encodable
    var query: String? { get set }
    var fileName: String? { get set }
    var fragmentsFileName: [String]? { get set }
    var variables: GenericType { get }
}

struct EmptyVariable: Encodable {}

struct GraphqlParameters<GenericType: Encodable>: GraphqlParametersProtocol {
    var fileName: String?
    var fragmentsFileName: [String]?
    var query: String?
    var variables: GenericType
}
