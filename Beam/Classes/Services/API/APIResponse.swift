import Foundation
import BeamCore
import os.log

protocol Errorable {
    var errors: [UserErrorData]? { get }
}

struct UserErrorData: Decodable {
    let message: String?
    let path: [String]?
}

extension APIRequest {
    /// Wrapper for result of GraphQL mutation
    struct APIResult<T>: Decodable where T: Decodable, T: Errorable {
        let data: APIResultWrapper<T>?
        let errors: [ErrorData]?
    }

    /// Wrapper for result of GraphQL query
    /// Unlike mutation, we don't need to add another wrapper
    /// around the data to extract the key.
    struct QueryResult<T>: Decodable  where T: Decodable, T: Errorable {
        var data: T?
        var errors: [ErrorData]?
    }

    class FetchDocument: DocumentAPIType, Errorable {
        static let codingKey = "document"
        let errors: [UserErrorData]? = nil
    }

    /// Wrapper for the data result of the GraphQL mutation result `APIResult`
    ///
    /// Use to generate the right `CodingKey` for generic json data.
    ///
    /// For example the setPasscode mutation returns the following json:
    /// ```
    /// data {
    ///     setPasscode {
    ///         passcodeSet
    ///     }
    ///}
    /// ```
    /// `APIResult<T>` is used to wrap the `data` level of the json, the `setPasscode` level is obtained
    /// from `T`. But the class used is `SetPasscode`, this wrapper is used to generate the `setPasscode` `CodingKey` from
    /// the `SetPasscode` class.
    ///
    struct APIResultWrapper<T>: Decodable, Errorable where T: Decodable, T: Errorable {
        let value: T?
        // Not sure about this errors. Don't think we will have something inside this.
        let errors: [UserErrorData]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let name = String(describing: T.self)
            let finalName: String

            if T.self == FetchDocument.self {
                finalName = FetchDocument.codingKey
            } else if T.self == Me.self {
                finalName = Me.codingKey
            } else {
                finalName = name.prefix(1).lowercased() + name.dropFirst()
            }

            guard let key = CodingKeys.key(named: finalName) else {
                throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: [], debugDescription: "Value not found at root level."))
            }

            do {
                value = try container.decode(T.self, forKey: key)
            } catch let error as DecodingError {
                switch error {
                case .valueNotFound:
                    // In case the error is value not found, we force the value to nil.
                    // Because this is a possible behavior.
                    value = nil
                case .keyNotFound(_, let context), .typeMismatch(_, let context):
                    Logger.shared.logError("🛑 APIResultWrapper init \(context.debugDescription)", category: .network)
                    throw error
                default:
                    Logger.shared.logError("🛑 APIResultWrapper init \(error.localizedDescription)", category: .network)
                    throw error
                }
            } catch {
                Logger.shared.logError("🛑 APIResultWrapper init \(error.localizedDescription)", category: .network)
                throw error
            }

            let errorsKey = CodingKeys(stringValue: "errors")
            errors = try? container.decode([UserErrorData]?.self, forKey: errorsKey!)
        }
    }

    private struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = "\(intValue)"
        }

        static func key(named name: String) -> CodingKeys? {
            return CodingKeys(stringValue: name)
        }
    }

    /// This matches the error at the GraphQL level, and not error
    /// returned by API, which are the `UserErrorData`
    struct ErrorData: Codable {
        let message: String?
        let extensions: ErrorExtensions?
        let locations: [ErrorLocation]?

        var explanations: [String]? {
            let explanations = extensions?.problems?.compactMap { problem in
                problem.explanation
            }
            return explanations
        }
    }

    struct ErrorExtensions: Codable {
        let code: String?
        let typeName: String?
        let fieldName: String?
        let problems: [ErrorExtensionsProblem]?
    }

    struct ErrorExtensionsProblem: Codable {
        let explanation: String?
        let path: [String?]?
    }

    struct ErrorLocation: Codable {
        let column: Int
        let line: Int
    }
}
