import Foundation
import os.log
import BeamCore
import Vinyl

extension APIRequest {
    @discardableResult
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil,
                                                                                completionHandler: @escaping (Swift.Result<T, Error>) -> Void) throws -> Foundation.URLSessionDataTask {
        guard FeatureFlags.current.syncEnabled else {
            throw APIRequestError.syncDisabledByFeatureFlag
        }

        let request = try makeUrlRequest(bodyParamsRequest, authenticatedCall: authenticatedCall)

        let filename = bodyParamsRequest.fileName ?? "no filename"

        #if DEBUG
        Self.networkCallFilesLock {
            Self.networkCallFiles.append(filename)
        }

        if !Self.expectedCallFiles.isEmpty, !Self.expectedCallFiles.starts(with: Self.networkCallFiles) {
            Logger.shared.logDebug("Expected network calls: \(Self.expectedCallFiles)", category: .network)
            Logger.shared.logDebug("Current network calls: \(Self.networkCallFiles)", category: .network)
            Logger.shared.logError("Current network calls is different from expected", category: .network)
        }
        #endif

        if Configuration.env == .test, !BeamURLSession.shouldNotBeVinyled, !(BeamURLSession.shared is Turntable), !ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument) {
            fatalError("All network calls must be caught by Vinyl in test environment. \(filename) was called.")
        }

        // Note: all `completionHandler` call must use `backgroundQueue.async` because if the
        // code called in the completion handler is blocking, it will prevent new following requests
        // to be parsed in the NSURLSession delegate callback thread

        let localTimer = Date()

        #if DEBUG
        Logger.shared.logDebug("Calling \(filename)", category: .network)
        #endif

        dataTask = BeamURLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            self.parseDataTask(data: data,
                               response: response,
                               error: error,
                               filename: filename,
                               authenticatedCall: authenticatedCall,
                               localTimer: localTimer,
                               completionHandler: completionHandler)
        }

        dataTask?.resume()

        if self.cancelRequest { dataTask?.cancel() }

        return dataTask!
    }

    static var networkCallFiles: [String] = []
    static var expectedCallFiles: [String] = []
    static let networkCallFilesLock = NSLock()

    static public func clearNetworkCallsFiles() {
        Self.networkCallFilesLock {
            Self.networkCallFiles = []
            Self.expectedCallFiles = []
        }
    }

    func logRequest(_ filename: String,
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
            Logger.shared.logError("Wrong HTTP Response for \(filename): \(String(describing: response))",
                                   category: .network)
            return
        }
        let diffTime = Date().timeIntervalSince(localTimer)
        let diff = String(format: "%.3f", diffTime)
        let request_id = httpResponse.allHeaderFields["X-Request-Id"] ?? "-"

        var extraGzipInformation = ""
        if let encoding = httpResponse.allHeaderFields["Content-Encoding"] as? String, encoding == "gzip" {
            extraGzipInformation = "(gzip)"
        }

        let text = "[\(request_id)] [\(callsCount)] [\(Self.uploadedBytes.byteSize)/\(Self.downloadedBytes.byteSize)] [\(bytesSent.byteSize)/\(bytesReceived.byteSize)] \(extraGzipInformation) [\(authenticated ? "authenticated" : "anonymous")] \(diff)sec \(httpResponse.statusCode) \(filename)"

        if diffTime > 1.0 {
            Logger.shared.logDebug("🐢🐢🐢 \(text)", category: .network)
        } else {
            Logger.shared.logDebug(text, category: .network)
        }
        #endif
    }

    func logCancelledRequest(_ filename: String,
                             _ localTimer: Date) {
        #if DEBUG_API_0
        let diffTime = Date().timeIntervalSince(localTimer)
        let diff = String(format: "%.2f", diffTime)
        Logger.shared.logDebug("\(diff)sec cancelled \(filename)", category: .network)
        #endif
    }

    func manageResponse<T: Decodable & Errorable>(_ data: Data?,
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

            let localTimer = Date()
            let jsonStruct = try self.defaultDecoder().decode(APIRequest.APIResult<T>.self, from: data)
            let diffTime = Date().timeIntervalSince(localTimer)
            if diffTime > 0.1 {
                Logger.shared.logWarning("Parsed network response from JSON to Beam Objects",
                                         category: .network,
                                         localTimer: localTimer)
            }

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
