import Foundation
import Alamofire
import os.log
import PromiseKit
import PMKFoundation
import Promises

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
class APIRequest {
    var route: String { "https://\(Configuration.apiHostname)/graphql" }
    let headers: HTTPHeaders = [
        "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
        "Accept": "application/json",
        "Accept-Language": Locale.current.languageCode ?? ""
    ]

    var authenticatedAPICall = true
    static var callsCount = 0
    private static var uploadedBytes: Int64 = 0
    private static var downloadedBytes: Int64 = 0
    let backgroundQueue = DispatchQueue.global(qos: .background)

    private func makeUrlRequest<E: GraphqlParametersProtocol>(_ bodyParamsRequest: E, authenticatedCall: Bool?) throws -> URLRequest {
        guard let url = URL(string: route) else { fatalError("Can't get URL: \(route)") }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
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

        let queryStruct = loadQuery(bodyParamsRequest)

        if let queryData = try? JSONEncoder().encode(queryStruct) {
            request.httpBody = queryData
        }
        assert(request.httpBody != nil)

        return request
    }

    struct FileUpload {
        let contentType: String
        let binary: Data
        let filename: String
        var variableName: String = "file"
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

    // swiftlint:disable:next cyclomatic_complexity
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

    // swiftlint:disable:next cyclomatic_complexity
    func handleError<T: Decodable>(result: APIResult<T>) -> Error {
        let error: Error
        if let errors = result.errors, !errors.isEmpty {
            error = handleTopLevelErrors(errors)
        } else if let errors = result.data?.errors, !errors.isEmpty {
            error = APIRequestError.apiError(extractUserErrorMessages(errors))
        } else if let errors = result.data?.value?.errors, !errors.isEmpty {
            // Sync issue sending an updated version of our document,
            // server denied updating it as checksum sent is different
            // from checksum on the server
            if errors.count == 1, errors[0].message == "Differs from current checksum" {
                error = APIRequestError.documentConflict
            } else {
                error = APIRequestError.apiError(extractUserErrorMessages(errors))
            }
        } else {
            error = APIRequestError.parserError
        }

        Logger.shared.logError(error.localizedDescription, category: .network)

        return error
    }

    func handleError<T: Errorable>(_ result: T) -> Error? {
        guard let errors = result.errors, !errors.isEmpty else { return nil }
        let error = APIRequestError.apiError(extractUserErrorMessages(errors))

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

    func defaultEncoder() -> ParameterEncoder {
        let encoder = JSONParameterEncoder()
        encoder.encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func loadFile(fileName: String) -> String? {
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "graphql") {
            return try? String(contentsOfFile: filepath)
        }
        return nil
    }
}

// MARK: Alamofire
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
            #if DEBUG_API_0
            let diffTime = Date().timeIntervalSince(localTimer)
            let diff = String(format: "%.2f", diffTime)

            let httpStatus = response.response?.statusCode ?? 0
            Logger.shared.logDebug("[\(callsCount)] [\(uploadedBytes.byteSize)/\(downloadedBytes.byteSize)] [\(authenticated ? "authenticated" : "anonymous")] \(diff)sec \(httpStatus) \(fileName)", category: .network)
            #endif

            #if DEBUG_API_1
            if let httpBodyData = response.request?.httpBody,
               let httpBody = String(data: httpBodyData, encoding: .utf8) {
                let httpStatus = response.response?.statusCode ?? 0
                Logger.shared.logDebug("\(httpStatus) " + httpBody.replacingOccurrences(of: "\\n", with: ""), category: .network)
            }
            #endif

            #if DEBUG_API_2
            self.cURLDescription { curl in
                debugPrint("=======================================")
                debugPrint(response)
                debugPrint(curl)
                debugPrint("=======================================")
            }
            #endif
        }
    }
}

extension APIRequest {
    // swiftlint:disable:next function_body_length
    func performRequest<T: Decodable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                    authenticatedCall: Bool? = nil,
                                                                    completionHandler: @escaping (Swift.Result<T, Error>) -> Void) -> DataRequest? {
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
        let encoder = defaultEncoder()

        let queue = DispatchQueue(label: "co.beam.api", qos: .background, attributes: .concurrent)

        let request = AF.request(route,
                                 method: .post,
                                 parameters: loadQuery(bodyParamsRequest),
                                 encoder: encoder,
                                 headers: headers,
                                 interceptor: authenticatedAPICall ? AuthenticationHandler() : nil)

        let localTimer = Date()
        let fileName = bodyParamsRequest.fileName ?? "no filename"

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
            .responseDecodable(queue: queue, decoder: decoder) { (response: DataResponse<T, AFError>) in
                self.manageResponse(response: response, filename: fileName) { [weak self] result in
                    switch result {
                    case .failure(let error):
                        completionHandler(.failure(error))
                        self?.handleNetworkError(error)
                    case .success(let data):
                        completionHandler(.success(data))
                    }
                }
            }

        return request
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
                                                                          completionHandler: @escaping (Swift.Result<T, Error>) -> Void) -> DataRequest? {
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

        let request = AF.upload(multipartFormData: multipartFormDataHandler,
                                to: route,
                                method: .post,
                                headers: headers,
                                interceptor: authenticatedAPICall ? AuthenticationHandler() : nil)

        let localTimer = Date()
        let fileName = bodyParamsRequest.fileName ?? "no filename"

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
        .responseDecodable(queue: queue, decoder: decoder) { (response: DataResponse<T, AFError>) in
            self.manageResponse(response: response, filename: fileName) { [weak self] result in
                switch result {
                case .failure(let error):
                    completionHandler(.failure(error))
                    self?.handleNetworkError(error)
                case .success(let data):
                    completionHandler(.success(data))
                }
            }
        }

        return request
    }
    //swiftlint:enable function_body_length

    private func manageResponse<T: Decodable>(response: DataResponse<T, AFError>,
                                              filename: String,
                                              completionHandler: @escaping (Swift.Result<T, Error>) -> Void) {
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
            switch response.result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let decodable):
                completionHandler(.success(decodable))
            }
        }
    }
}

// MARK: Foundation
extension APIRequest {
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil,
                                                                                completionHandler: @escaping (Swift.Result<T, Error>) -> Void) throws -> URLSessionDataTask? {
        let request = try makeUrlRequest(bodyParamsRequest, authenticatedCall: authenticatedCall)

        let dataTask = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) -> Void in
            if let error = error {
                completionHandler(.failure(error))
                self?.handleNetworkError(error)
                return
            }

            do {
                if let value: T = try self?.manageResponse(data, response) {
                    completionHandler(.success(value))
                }
            } catch {
                completionHandler(.failure(error))
            }
        }

        Self.callsCount += 1

        dataTask.resume()

        return dataTask
    }

    private func manageResponse<T: Decodable & Errorable>(_ data: Data?,
                                                          _ response: URLResponse?) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIRequestError.parserError
        }

        switch httpResponse.statusCode {
        case 401:
            NotificationCenter.default.post(name: .networkUnauthorized, object: self)
            throw APIRequestError.unauthorized
        case 403:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .networkForbidden, object: self)
            }
            throw APIRequestError.forbidden
        case 404:
            throw APIRequestError.notFound
        case 500:
            throw APIRequestError.internalServerError
        default:
            guard let data = data else {
                throw APIRequestError.parserError
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.shared.logError("Network error \(String(describing: response))", category: .network)
                throw APIRequestError.error
            }

            let jsonStruct = try self.defaultDecoder().decode(APIRequest.APIResult<T>.self, from: data)

            guard let value = jsonStruct.data?.value else {
                throw APIRequestError.parserError
            }

            if let error = self.handleError(value) {
                throw error
            }

            return value
        }
    }

}

// MARK: PromiseKit
extension APIRequest {
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> PromiseKit.Promise<T> {
        Self.callsCount += 1

        return firstly {
            URLSession.shared.dataTask(.promise,
                                       with: try self.makeUrlRequest(bodyParamsRequest, authenticatedCall: authenticatedCall))
        }.map(on: backgroundQueue) {
            return try self.manageResponse($0.data, $0.response)
        }.then(on: backgroundQueue) { (data: T) -> PromiseKit.Promise<T> in
            if let error = self.handleError(data) {
                throw error
            }

            return .value(data)
        }
    }
}

// MARK: Promises
extension APIRequest {
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> Promises.Promise<T> {

        return Promises.Promise { fulfill, reject in
            do {
                let _: URLSessionDataTask? = try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                     authenticatedCall: authenticatedCall) { (result: Swift.Result<T, Error>) in
                    switch result {
                    case .failure(let error):
                        reject(error)
                    case .success(let dataResult):
                        fulfill(dataResult)
                    }
                }
            } catch {
                reject(error)
            }
        }
    }
}
// swiftlint:enable file_length
