import Foundation
import os.log
import BeamCore
import Vinyl

// swiftlint:disable file_length

class BeamURLSession {
    static var shared = URLSession.shared
    static var shouldNotBeVinyled = false
    static func reset() {
        Self.shared = URLSession.shared
    }
}

// swiftlint:disable:next type_body_length
class APIRequest: NSObject {
    var route: String { "\(Configuration.apiHostname)/graphql" }
    var authenticatedAPICall = true
    static var callsCount = 0
    static var uploadedBytes: Int64 = 0
    static var downloadedBytes: Int64 = 0
    let backgroundQueue = DispatchQueue(label: "APIRequest backgroundQueue", qos: .userInitiated)
    var dataTask: Foundation.URLSessionDataTask?
    var cancelRequest: Bool = false

    static var deviceId = UUID() // TODO: Persist this in Persistence

    var isCancelled: Bool {
        cancelRequest
    }

    func makeUrlRequest<E: GraphqlParametersProtocol>(_ bodyParamsRequest: E, authenticatedCall: Bool?) throws -> URLRequest {
        guard let url = URL(string: route) else { fatalError("Can't get URL: \(route)") }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "Device": Self.deviceId.uuidString.lowercased(),
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Accept-Language": Locale.current.languageCode ?? "en"
        ]

        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        if authenticatedCall ?? authenticatedAPICall {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()

            guard AuthenticationManager.shared.isAuthenticated,
                  let accessToken = AuthenticationManager.shared.accessToken else {
                LibrariesManager.nonFatalError(error: APIRequestError.notAuthenticated,
                                               addedInfo: AuthenticationManager.shared.hashTokensInfos())

                NotificationCenter.default.post(name: .networkUnauthorized, object: self)
                throw APIRequestError.notAuthenticated
            }

            request.setValue("Bearer " + accessToken,
                             forHTTPHeaderField: "Authorization")
        }

        var queryStruct = loadQuery(bodyParamsRequest)

        // Remove files
        let files = queryStruct.files
        queryStruct.files = nil

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds
        #if DEBUG
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        #else
        encoder.outputFormatting = [.withoutEscapingSlashes]
        #endif

        if let queryData = try? encoder.encode(queryStruct) {
            #if DEBUG_API_1
            if let queryDataString = queryData.asString {
//                if let jsonResult = try JSONSerialization.jsonObject(with: queryData, options: []) as? NSDictionary {
//                    Logger.shared.logDebug("-> HTTP Request:\n\(jsonResult.description)", category: .network)
//                }
//                #if DEBUG_API_2
                Logger.shared.logDebug("-> HTTP Request: \(route)\n\(queryDataString.replacingOccurrences(of: "\\n", with: "\n"))",
                                       category: .network)
//                #endif
            } else {
                assert(false)
            }
            #endif
            request.httpBody = queryData
        }
        assert(request.httpBody != nil)

        if files != nil {
            //     urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

//            request.allHTTPHeaderFields

        } else {

        }

        return request
    }

    private func createMultipartBody<E: GraphqlParametersProtocol>(_ bodyParamsRequest: E,
                                                                   boundary: String?,
                                                                   files: [GraphqlFileUpload]) -> Data {
        var result = Data()
        let boundary = boundary ?? UUID().uuidString
        let lineBreak = "\r\n"

        for file in files {
            result.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
            result.append("Content-Disposition: form-data; name=\"\(file.variableName)\"; filename=\"\(file.variableName)\"\(lineBreak)".asData)
            result.append("Content-Type: \(file.contentType)\(lineBreak)\(lineBreak)".asData)
            result.append(file.binary)
        }

        return result
    }

    // If request contains a filename but no query, load the query from fileName
    func loadQuery<T: GraphqlParametersProtocol>(_ bodyParamsRequest: T) -> T {
        if bodyParamsRequest.fileName == nil && bodyParamsRequest.query == nil {
            LibrariesManager.nonFatalError("Missing fileName or query in GraphqlParameters")
        }

        var updatedRequest = bodyParamsRequest
        updatedRequest.fileName = nil // Remove fileName from GraphqlParameters
        updatedRequest.fragmentsFileName = nil // Remove fragmentFileName from GraphqlParameters
        updatedRequest.query = {
            var fragment = ""
            // if there is a fragmentsFileName load them.
            if let fragmentsFileName = bodyParamsRequest.fragmentsFileName {
                for fragmentFileName in fragmentsFileName {
                    fragment.append(contentsOf: loadFile(fileName: fragmentFileName) ?? "")
                }
            }

            // Query already loaded
            if let query = bodyParamsRequest.query { return query + fragment }
            // Load query from fileName.
            if let fileName = bodyParamsRequest.fileName, let query = loadFile(fileName: fileName) {
                return query + fragment
            }

            // Missing query
            fatalError("File \(bodyParamsRequest.fileName ?? "") not found")
        }()

        return updatedRequest
    }

    func handleNetworkError(_ error: Error) {
        switch error {
        case APIRequestError.unauthorized, APIRequestError.forbidden:
            break
        default:
            let nsError = error as NSError
            Logger.shared.logError("\(nsError) - \(nsError.userInfo)", category: .network)
            LibrariesManager.nonFatalError(error: error)
        }
    }

    private func handleTopLevelErrors(_ errors: [ErrorData]) -> Error {
        let error: Error
        if errors[0].message == "Couldn't find Device" {
            error = APIRequestError.deviceNotFound
        } else {
            let message = extractErrorMessages(errors)
            error = APIRequestError.apiError(message)
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

    // swiftlint:disable:next cyclomatic_complexity
    func handleError<T: Decodable>(result: QueryResult<T>) -> Error {
        let error: Error
        if let errors = result.errors, !errors.isEmpty {
            error = handleTopLevelErrors(errors)
        } else if let errorable = result.data,
                  let errors = errorable.errors,
                  !errors.isEmpty {
            error = APIRequestError.apiErrors(errorable)
        } else {
            error = APIRequestError.parserError
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

    // swiftlint:disable:next cyclomatic_complexity
    func handleError<T: Decodable>(result: APIResult<T>) -> Error {
        let error: Error
        if let errors = result.errors, !errors.isEmpty {
            error = handleTopLevelErrors(errors)
        } else if let errors = result.data?.errors, !errors.isEmpty {
            error = APIRequestError.apiError(extractUserErrorMessages(errors))
        } else if let errors = result.data?.value?.errors, !errors.isEmpty {
            error = APIRequestError.apiError(extractUserErrorMessages(errors))
        } else {
            error = APIRequestError.parserError
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

    func handleError<T: Errorable>(_ result: T) -> Error? {
        let error: Error

        guard let errors = result.errors, !errors.isEmpty else { return nil }
        if errors.count == 1, errors[0].isErrorInvalidChecksum {
            error = APIRequestError.beamObjectInvalidChecksum(result)
        } else if errors.count == 1,
                  errors[0].path == ["attributes", "title"],
                  errors[0].message == "Title has already been taken" {
            error = APIRequestError.duplicateTitle
        } else {
            error = APIRequestError.apiErrors(result)
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

    private func extractUserErrorMessages(_ errors: [UserErrorData]) -> [String] {
        return errors.compactMap {
            var errorMessage: String = ""
            errorMessage.append("[\($0.path?.joined(separator: ", ") ?? "no path")]: ")
            errorMessage.append($0.message ?? "No error message")

            return errorMessage
        } as [String]
    }

    func extractErrorMessages(_ errors: [ErrorData]) -> [String] {
        return errors.compactMap {
            var errorMessage: String = ""
            if let message = $0.message { errorMessage.append("\(message) - ") }

            if let explanations = $0.explanations {
                errorMessage.append(explanations.joined(separator: " "))
            }

            return errorMessage
        } as [String]
    }

    func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        return decoder
    }

    func loadFile(fileName: String) -> String? {
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "graphql") {
            return try? String(contentsOfFile: filepath)
        }
        return nil
    }

    func cancel() {
        dataTask?.cancel()
        cancelRequest = true
    }
}
// swiftlint:enable file_length
