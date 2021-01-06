import Foundation
import Alamofire
import os.log

// swiftlint:disable file_length

enum APIRequestError: Error, Equatable {
    case forbidden
    case unauthorized
    case internalServerError
    case parserError
    case deviceNotFound
    case notAuthenticated
    case apiError([String])
}

extension APIRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .parserError:
            return loc("error.api.requestError.parserError")
        case .forbidden:
            return loc("error.api.requestError.forbidden")
        case .unauthorized:
            return loc("error.api.requestError.unauthorized")
        case .deviceNotFound:
            return loc("error.api.requestError.deviceNotFound")
        case .internalServerError:
            return loc("error.api.internalServerError")
        case .notAuthenticated:
            return loc("error.api.requestError.notAuthenticated")
        case .apiError(let explanations):
            return explanations.joined(separator: ", ")
        }
    }
}

class APIRequest {
    var route: String { "https://\(Configuration.apiHostname)/graphql" }
    let headers: HTTPHeaders = [
        "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
        "Accept": "application/json",
        "Accept-Language": Locale.current.languageCode ?? ""
    ]

    var authenticatedAPICall = true
    private static var callsCount = 0
    private static var uploadedBytes: Int64 = 0
    private static var downloadedBytes: Int64 = 0

    // swiftlint:disable:next function_body_length
    func performRequest<T: Decodable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                    authenticatedCall: Bool? = nil,
                                                                    completionHandler: @escaping (Result<T, Error>) -> Void) -> DataRequest? {
        let isCallAuthenticated = authenticatedCall ?? authenticatedAPICall
        if isCallAuthenticated {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()

            guard AuthenticationManager.shared.isAuthenticated else {
                LibrariesManager.nonFatalError(error: APIRequestError.notAuthenticated,
                                               addedInfo: AuthenticationManager.shared.hashTokensInfos())

                completionHandler(.failure(APIRequestError.notAuthenticated))
                NotificationCenter.default.post(name: .networkUnauthorized, object: self)
                return nil
            }
        }

        let decoder = defaultDecoder()
        let queue = DispatchQueue(label: "co.beam.api", qos: .background, attributes: .concurrent)

        let request = AF.request(route,
                                 method: .post,
                                 parameters: loadQuery(bodyParamsRequest),
                                 encoder: JSONParameterEncoder.default,
                                 headers: headers,
                                 interceptor: authenticatedAPICall ? AuthenticationHandler() : nil)

        let localTimer = Date()
        let fileName = bodyParamsRequest.fileName ?? "Unknown"

        Self.callsCount += 1

        request.validate(statusCode: 200..<300)
            .uploadProgress { progress in
                Self.uploadedBytes += progress.completedUnitCount

            }
            .downloadProgress { progress in
                Self.downloadedBytes += progress.completedUnitCount
            }
            .debugJson(queue: queue,
                       fileName: fileName,
                       localTimer: localTimer,
                       authenticated: authenticatedAPICall,
                       callsCount: Self.callsCount,
                       uploadedBytes: Self.uploadedBytes,
                       downloadedBytes: Self.downloadedBytes)
            .responseDecodable(queue: queue, decoder: decoder) { (response: DataResponse<T>) in
                self.manageResponse(response: response, filename: fileName) { [weak self] result in
                    switch result {
                    case .failure(let error):
                        completionHandler(.failure(APIRequestError.apiError(["\(Configuration.apiHostname): \(error.localizedDescription)"])))
                        self?.handleNetworkError(error)
                    case .success(let data):
                        completionHandler(.success(data))
                    }
                }
            }

        return request
    }

    struct FileUpload {
        let contentType: String
        let binary: Data
        let filename: String
        var variableName: String = "file"
    }

    /// Upload binaries
    /// - Parameter bodyParamsRequest:
    /// - Parameter files: ["file": UIImage] the key of the Dictionary must be the same as used inside the variables name in the GraphQL query
    /// - Parameter uploadHandler
    /// - Parameter completionHandler:
    //swiftlint:disable function_body_length
    func performUploadRequest<T: Decodable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                          files: [FileUpload],
                                                                          uploadHandler: ((Progress) -> Void)? = nil,
                                                                          completionHandler: @escaping (Result<T, Error>) -> Void) -> DataRequest? {
        if authenticatedAPICall {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()

            guard AuthenticationManager.shared.isAuthenticated else {
                LibrariesManager.nonFatalError(error: APIRequestError.notAuthenticated,
                                               addedInfo: AuthenticationManager.shared.hashTokensInfos())
                completionHandler(.failure(APIRequestError.notAuthenticated))
                NotificationCenter.default.post(name: .networkUnauthorized, object: self)
                return nil
            }
        }

        let decoder = defaultDecoder()
        let encoder = JSONEncoder()

        let queue = DispatchQueue(label: "co.beam.api", qos: .background, attributes: .concurrent)

        // When uploading files, GraphqQL expects a different format for binary uploads. The Curl examples would be:
        // curl localhost:4000/graphql \
        //  -F operations='{ "query": "mutation ($poster: Upload) { createPost(id: 5, poster: $poster) { id } }", "variables": { "poster": null } }' \
        //  -F map='{ "0": ["variables.poster"] }' \
        //  -F 0=@package.json
        // let multipartFormData = MultipartFormData(fileManager: .default)
        let multipartFormDataHandler: (MultipartFormData) -> Void = { multipartFormData in
            do {
                // Put the full query + variables into `operations`
                let data = try encoder.encode(self.loadQuery(bodyParamsRequest))
                multipartFormData.append(data, withName: "operations")

                // Add files and send a `map` connecting the files to their variables
                var mapperDictionary: [String: [String]] = [:]
                for file in files {
                    multipartFormData.append(file.binary,
                                             withName: file.variableName,
                                             fileName: file.filename,
                                             mimeType: file.contentType)
                    // Using a string for Index on purpose
                    mapperDictionary[file.variableName] = ["variables.\(file.variableName)"]
                }

                let mapper = try encoder.encode(mapperDictionary)
                multipartFormData.append(mapper, withName: "map")
            } catch {
                completionHandler(.failure(error))
                LibrariesManager.nonFatalError(error: error)
            }
        }

        var uploadHeaders = headers
        uploadHeaders["Content-type"] = "multipart/form-data"

        let request = AF.upload( multipartFormData: multipartFormDataHandler,
                                 usingThreshold: 10_000_000,
                                 to: route,
                                 method: .post,
                                 headers: headers,
                                 interceptor: authenticatedAPICall ? AuthenticationHandler() : nil)

        let localTimer = Date()
        let fileName = bodyParamsRequest.fileName ?? "Unknown"

        Self.callsCount += 1

        request.uploadProgress { progress in
            Self.uploadedBytes += progress.completedUnitCount
            uploadHandler?(progress)
        }
        .downloadProgress { progress in
            Self.downloadedBytes += progress.completedUnitCount
        }
        .debugJson(queue: queue,
                   fileName: fileName,
                   localTimer: localTimer,
                   authenticated: authenticatedAPICall,
                   callsCount: Self.callsCount,
                   uploadedBytes: Self.uploadedBytes,
                   downloadedBytes: Self.downloadedBytes)
        .responseDecodable(queue: queue, decoder: decoder) { (response: DataResponse<T>) in
            self.manageResponse(response: response, filename: fileName) { [weak self] result in
                switch result {
                case .failure(let error):
                    completionHandler(.failure(APIRequestError.apiError(["\(Configuration.apiHostname): \(error.localizedDescription)"])))
                    self?.handleNetworkError(error)
                case .success(let data):
                    completionHandler(.success(data))
                }
            }
        }

        return request
    }
    //swiftlint:enable function_body_length

    private func manageResponse<T: Decodable>(response: DataResponse<T>,
                                              filename: String,
                                              completionHandler: @escaping (Result<T, Error>) -> Void) {
        if let statusCode = response.response?.statusCode, [401, 403].contains(statusCode) {
            var addedInfo = AuthenticationManager.shared.hashTokensInfos()
            addedInfo["graphql_request"] = filename
            LibrariesManager.nonFatalError("Network \(statusCode)",
                                           addedInfo: addedInfo)
        }

        switch response.response?.statusCode {
        case 401:
            completionHandler(.failure(APIRequestError.unauthorized))
            NotificationCenter.default.post(name: .networkUnauthorized, object: self)
        case 403:
            completionHandler(.failure(APIRequestError.forbidden))
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .networkForbidden, object: self)
            }
        case 500:
            completionHandler(.failure(APIRequestError.internalServerError))
        default:
            completionHandler(response.result)
        }
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

    private func handleNetworkError(_ error: Error) {
        if [APIRequestError.unauthorized, APIRequestError.forbidden].contains(error as? APIRequestError) {
            // Request unauthorized
        } else if let aferror = error as? AFError, aferror.isExplicitlyCancelledError {
            // Request explicitly cancelled
        } else {
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

    func handleError<T: Decodable>(result: QueryResult<T>) -> Error {
        let error: Error
        if let errors = result.errors, !errors.isEmpty {
            error = handleTopLevelErrors(errors)
        } else if let errors = result.data?.errors, !errors.isEmpty {
            error = APIRequestError.apiError(extractUserErrorMessages(errors))
        } else {
            error = APIRequestError.parserError
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

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

    private func extractUserErrorMessages(_ errors: [UserErrorData]) -> [String] {
        return errors.compactMap {
            var errorMessage: String = ""
            if let message = $0.message { errorMessage.append(message) }

            return errorMessage
        } as [String]
    }

    private func extractErrorMessages(_ errors: [ErrorData]) -> [String] {
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
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func loadFile(fileName: String) -> String? {
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "graphql") {
            return try? String(contentsOfFile: filepath)
        }
        return nil
    }
}

extension DataRequest {
    // swiftlint:disable:next function_parameter_count
    public func debugJson(queue: DispatchQueue,
                          fileName: String,
                          localTimer: Date,
                          authenticated: Bool,
                          callsCount: Int,
                          uploadedBytes: Int64,
                          downloadedBytes: Int64) -> Self {
        return self.responseJSON(queue: queue) { response in
//            #if DEBUG_API_0
            let diffTime = Date().timeIntervalSince(localTimer)
            let diff = String(format: "%.2f", diffTime)

            let httpStatus = response.response?.statusCode ?? 0
            Logger.shared.logDebug("[\(callsCount)] [\(uploadedBytes.byteSize)/\(downloadedBytes.byteSize)] [\(authenticated ? "authenticated" : "anonymous")] \(diff)sec \(httpStatus) \(fileName)", category: .network)
//            #endif

            #if DEBUG_API_1
            if let httpBodyData = response.request?.httpBody,
               let httpBody = String(data: httpBodyData, encoding: .utf8) {
                let httpStatus = response.response?.statusCode ?? 0
                Logger.shared.logDebug("\(httpStatus) " + httpBody.replacingOccurrences(of: "\\n", with: ""), category: .network)
            }
            #endif

            #if DEBUG_API_2
            debugPrint("=======================================")
            debugPrint(response)
            debugPrint(self.debugDescription)
            debugPrint("=======================================")
            #endif
        }
    }
}
// swiftlint:enable file_length
