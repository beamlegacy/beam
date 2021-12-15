import Foundation
import os.log
import PromiseKit
import PMKFoundation
import Promises
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
    private static var uploadedBytes: Int64 = 0
    private static var downloadedBytes: Int64 = 0
    let backgroundQueue = DispatchQueue(label: "APIRequest backgroundQueue", qos: .userInitiated)
    private(set) var dataTask: Foundation.URLSessionDataTask?
    private var cancelRequest: Bool = false

    static var deviceId = UUID() // TODO: Persist this in Persistence

    var isCancelled: Bool {
        cancelRequest
    }

    private func makeUrlRequest<E: GraphqlParametersProtocol>(_ bodyParamsRequest: E, authenticatedCall: Bool?) throws -> URLRequest {
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

        let queryStruct = loadQuery(bodyParamsRequest)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds

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

// MARK: Foundation
extension APIRequest {
    @discardableResult
    //swiftlint:disable:next function_body_length
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil,
                                                                                completionHandler: @escaping (Swift.Result<T, Error>) -> Void) throws -> Foundation.URLSessionDataTask {

        let request = try makeUrlRequest(bodyParamsRequest, authenticatedCall: authenticatedCall)

        let filename = bodyParamsRequest.fileName ?? "no filename"
        let localTimer = BeamDate.now
        let callsCount = Self.callsCount

        #if DEBUG
        Self.networkCallFilesSemaphore.wait()
        Self.networkCallFiles.append(filename)
        Self.networkCallFilesSemaphore.signal()

        if !Self.expectedCallFiles.isEmpty, !Self.expectedCallFiles.starts(with: Self.networkCallFiles) {
            Logger.shared.logDebug("Expected network calls: \(Self.expectedCallFiles)", category: .network)
            Logger.shared.logDebug("Current network calls: \(Self.networkCallFiles)", category: .network)
            Logger.shared.logError("Current network calls is different from expected", category: .network)
        }
        #endif

        if Configuration.env == Configuration.unitTestModeLaunchArgument, !BeamURLSession.shouldNotBeVinyled, !(BeamURLSession.shared is Turntable), !ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument) {
            fatalError("All network calls must be caught by Vinyl in test environment. \(filename) was called.")
        }

        // Note: all `completionHandler` call must use `backgroundQueue.async` because if the
        // code called in the completion handler is blocking, it will prevent new following requests
        // to be parsed in the NSURLSession delegate callback thread

        dataTask = BeamURLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            guard let dataTask = self.dataTask else {
                self.backgroundQueue.async {
                    completionHandler(.failure(APIRequestError.parserError))
                }
                return
            }

            var countOfBytesReceived: Int64 = 0
            var countOfBytesSent: Int64 = 0

            if dataTask.responds(to: Selector(("countOfBytesReceived"))) {
                countOfBytesReceived = dataTask.countOfBytesReceived
            }

            if dataTask.responds(to: Selector(("countOfBytesSent"))) {
                countOfBytesSent = dataTask.countOfBytesSent
            }

            Self.downloadedBytes += countOfBytesReceived
            Self.uploadedBytes += countOfBytesSent
            Self.callsCount += 1

            // Quit early in case of already cancelled requests
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                /*
                 In such case, we already potentially sent and received all data, and maybe should just proceed like a
                 regular request if we can parse its result meaning it's a fullfilled request.

                 This way we can store the sent checksum as previousChecksum
                 */

                self.logCancelledRequest(filename, localTimer)
                self.backgroundQueue.async {
                    completionHandler(.failure(error))
                }
                return
            }

            self.logRequest(filename,
                            response,
                            localTimer,
                            callsCount,
                            countOfBytesSent,
                            countOfBytesReceived,
                            authenticatedCall ?? self.authenticatedAPICall)

            if let error = error {
                self.backgroundQueue.async {
                    completionHandler(.failure(error))
                }
                self.handleNetworkError(error)
                return
            }

            do {
                let value: T = try self.manageResponse(data, response)

                self.backgroundQueue.async {
                    completionHandler(.success(value))
                }
            } catch {
                self.backgroundQueue.async {
                    completionHandler(.failure(error))
                }
            }
        }

        dataTask?.resume()

        if self.cancelRequest { dataTask?.cancel() }

        return dataTask!
    }

    static var networkCallFiles: [String] = []
    static var expectedCallFiles: [String] = []
    static var networkCallFilesSemaphore = DispatchSemaphore(value: 1)

    static public func clearNetworkCallsFiles() {
        Self.networkCallFilesSemaphore.wait()
        Self.networkCallFiles = []
        Self.expectedCallFiles = []
        Self.networkCallFilesSemaphore.signal()
    }

    // swiftlint:disable:next function_parameter_count
    private func logRequest(_ filename: String,
                            _ response: URLResponse?,
                            _ localTimer: Date,
                            _ callsCount: Int,
                            _ bytesSent: Int64,
                            _ bytesReceived: Int64,
                            _ authenticated: Bool) {

        #if DEBUG
        if !Self.expectedCallFiles.isEmpty, !Self.expectedCallFiles.starts(with: Self.networkCallFiles) {
            Logger.shared.logDebug("Expected network calls: \(Self.expectedCallFiles)", category: .network)
            Logger.shared.logDebug("Current network calls: \(Self.networkCallFiles)", category: .network)
            Logger.shared.logError("Current network calls is different from expected", category: .network)
        }
        #endif

        #if DEBUG_API_0
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.shared.logDebug("- \(filename)", category: .network)
            return
        }
        let diffTime = BeamDate.now.timeIntervalSince(localTimer)
        let diff = String(format: "%.2f", diffTime)
        let text = "[\(callsCount)] [\(Self.uploadedBytes.byteSize)/\(Self.downloadedBytes.byteSize)] [\(bytesSent.byteSize)/\(bytesReceived.byteSize)] [\(authenticated ? "authenticated" : "anonymous")] \(diff)sec \(httpResponse.statusCode) \(filename)"

        if diffTime > 1.0 {
            Logger.shared.logDebug("🐢🐢🐢 \(text)", category: .network)
        } else {
            Logger.shared.logDebug(text, category: .network)
        }
        #endif
    }

    private func logCancelledRequest(_ filename: String,
                                     _ localTimer: Date) {
        #if DEBUG_API_0
        let diffTime = BeamDate.now.timeIntervalSince(localTimer)
        let diff = String(format: "%.2f", diffTime)
        Logger.shared.logDebug("\(diff)sec cancelled \(filename)", category: .network)
        #endif
    }

    // swiftlint:disable:next cyclomatic_complexity
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

            manageResponseLog(data)

            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.shared.logError("Network error \(String(describing: response))", category: .network)
                throw APIRequestError.error
            }

            let jsonStruct = try self.defaultDecoder().decode(APIRequest.APIResult<T>.self, from: data)

            if let errors = jsonStruct.errors, !errors.isEmpty {
                throw APIRequestError.apiRequestErrors(errors)
            }

            guard let value = jsonStruct.data?.value else {
                // When the API returns top level errors
                if let errors = jsonStruct.errors {
                    throw APIRequestError.apiError(extractErrorMessages(errors))
                }

                throw APIRequestError.parserError
            }

            /*
             Manage errors returned by our GraphQL user codebase. Request was properly handled
             by the server but include errors like checksum issues.
             */
            if let error = self.handleError(value) {
                throw error
            }

            return value
        }
    }

    private func manageResponseLog(_ data: Data) {
        #if DEBUG_API_1
        if let dataString = data.asString {
//                if let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary {
//                    Logger.shared.logDebug("-> HTTP Response:\n\(jsonResult.description)", category: .network)
//                }
//            #if DEBUG_API_2
            Logger.shared.logDebug("-> HTTP Response:\n\(dataString.replacingOccurrences(of: "\\n", with: "\n"))",
                                   category: .network)
//            #endif
        } else {
            assert(false)
        }
        #endif
    }
}

// MARK: PromiseKit
extension APIRequest {
    /// Make a performRequest which can be cancelled later on calling the tuple
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> PromiseKit.Promise<T> {
        PromiseKit.Promise<T> { seal in
            do {
                guard !self.cancelRequest else { throw APIRequestError.operationCancelled }

                // I can't use the PromiseKit foundation data request as it doesn't return a task, and I can't
                // cancel it later
                try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                        authenticatedCall: authenticatedCall) { (result: Swift.Result<T, Error>) in
                    switch result {
                    case .failure(let error):
                        seal.reject(error)
                    case .success(let dataResult):
                        seal.fulfill(dataResult)
                    }
                }
            } catch {
                seal.reject(error)
            }
        }
    }
}

// MARK: Promises
extension APIRequest {
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> Promises.Promise<T> {
        wrap(on: backgroundQueue) { (handler: @escaping (Swift.Result<T, Error>) -> Void) in
            guard !self.cancelRequest else { throw APIRequestError.operationCancelled }
            try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                    authenticatedCall: authenticatedCall,
                                    completionHandler: handler)
        }.then(on: backgroundQueue) { result -> Promises.Promise<T> in
            return Promise(try result.get())
        }
    }
}
// swiftlint:enable file_length
