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

    // swiftlint:disable:next function_body_length
    func makeUrlRequest<E: GraphqlParametersProtocol>(_ bodyParamsRequest: E, authenticatedCall: Bool?) throws -> URLRequest {
        guard let url = URL(string: route) else { fatalError("Can't get URL: \(route)") }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "Device": Self.deviceId.uuidString.lowercased(),
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
            "Accept": "application/json",
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

        let graphqlQuery = try encoder.encode(queryStruct)

        // Will do a multipart upload
        if let files = files, !files.isEmpty {
            let boundary = "------------------------\(UUID().uuidString)"
            let lineBreak = "\r\n"
            var queryData = Data()

            // see https://www.floriangaechter.com/blog/graphql-file-uploading/ for example about file uploads & GraphQL
            // see RFC1521 for multipart https://datatracker.ietf.org/doc/html/rfc1521#page-29

            // Add the GraphQL query
            queryData.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
            queryData.append("Content-Disposition: form-data; name=\"operations\"\(lineBreak)\(lineBreak)".asData)
            queryData.append(graphqlQuery)

            var mapperDictionary: [String: [String]] = [:]

            for file in files {
                queryData.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
                queryData.append("Content-Disposition: form-data; name=\"\(file.filename)\"; filename=\"\(file.filename)\"\(lineBreak)".asData)
                queryData.append("Content-Type: \(file.contentType)\(lineBreak)\(lineBreak)".asData)
                queryData.append(file.binary)
//                queryData.append("This is the binary data".asData)

                mapperDictionary[file.filename] = ["variables.\(file.variableName)"]
            }

            queryData.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
            queryData.append("Content-Disposition: form-data; name=\"map\"\(lineBreak)\(lineBreak)".asData)
            let mapper = try encoder.encode(mapperDictionary)
            queryData.append(mapper)
            queryData.append("\(lineBreak)--\(boundary)--".asData)

            // Request headers
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("\(queryData.count)", forHTTPHeaderField: "Content-Length")

            request.httpBody = queryData
        } else {
            request.setValue("application/json",
                             forHTTPHeaderField: "Content-Type")
            request.httpBody = graphqlQuery
        }

        assert(request.httpBody != nil)

        #if DEBUG_API_1
        if let queryDataString = request.httpBody?.asString {
            //                if let jsonResult = try JSONSerialization.jsonObject(with: queryData, options: []) as? NSDictionary {
            //                    Logger.shared.logDebug("-> HTTP Request:\n\(jsonResult.description)", category: .network)
            //                }
            //                #if DEBUG_API_2
            Logger.shared.logDebug("-> HTTP Request: \(route)\n\(queryDataString.replacingOccurrences(of: "\\n", with: "\n"))",
                                   category: .network)
            //                #endif
        }
        #endif

        return request
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
