import Foundation

protocol GraphqlParametersProtocol: Encodable {
    associatedtype GenericType: Encodable
    var query: String? { get set }
    var fileName: String? { get set }
    var fragmentsFileName: [String]? { get set }
    var variables: GenericType { get }
    var files: [GraphqlFileUpload]? { get set }
}

struct EmptyVariable: Encodable {}

struct GraphqlParameters<GenericType: Encodable>: GraphqlParametersProtocol {
    var fileName: String?
    var fragmentsFileName: [String]?
    var query: String?
    var variables: GenericType
    var files: [GraphqlFileUpload]?
}

struct GraphqlFileUpload: Encodable {
    let contentType: String
    let binary: Data
    let filename: String
    var variableName: String = "file"
}
