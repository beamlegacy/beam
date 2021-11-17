import Foundation
import os.log
import BeamCore
import Vinyl

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

        if Configuration.env == "test", !BeamURLSession.shouldNotBeVinyled, !(BeamURLSession.shared is Turntable) {
            fatalError("All network calls must be catched by Vinyl in test environment. \(filename) was called.")
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
