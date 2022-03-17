import Foundation
import os.log
import BeamCore
import Vinyl

// swiftlint:disable file_length

class BeamURLSession {
    static var shared = URLSession(configuration: URLSessionConfiguration.default,
                                   delegate: BeamURLSessionDelegate(),
                                   delegateQueue: nil)
    static var shouldNotBeVinyled = false
    static func reset() {
        Self.shared = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: BeamURLSessionDelegate(),
                                 delegateQueue: nil)
    }
}

class BeamURLSessionDelegate: NSObject, URLSessionDelegate {
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // We only allow self-signed certificates for dev and test.
        if let trust = challenge.protectionSpace.serverTrust,
           [.test, .debug].contains(Configuration.env) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.useCredential, nil)
        }
    }
}

// swiftlint:disable:next type_body_length
class APIRequest: NSObject {
    var route: String { "\(Configuration.apiHostname)/graphql" }
    var authenticatedAPICall = true
    static var callsCount = 0
    static var uploadedBytes: Int64 = 0
    static var downloadedBytes: Int64 = 0
    // Using `userInteractive` for instant
    let backgroundQueue = DispatchQueue(label: "APIRequest backgroundQueue", qos: .userInteractive)
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
//            "Accept-Encoding": "gzip, deflate, br"
        ]

        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        // Authentication headers
        if authenticatedCall ?? authenticatedAPICall {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()

            guard AuthenticationManager.shared.isAuthenticated,
                  let accessToken = AuthenticationManager.shared.accessToken else {
                      ThirdPartyLibrariesManager.shared.nonFatalError(error: APIRequestError.notAuthenticated,
                                               addedInfo: AuthenticationManager.shared.hashTokensInfos())

                NotificationCenter.default.post(name: .networkUnauthorized, object: self)
                throw APIRequestError.notAuthenticated
            }

            request.setValue("Bearer " + accessToken,
                             forHTTPHeaderField: "Authorization")
        }

        var queryStruct = loadQuery(bodyParamsRequest)

        // Remove attached files before the encoding of the GraphQL query
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

        /*
         We will use multipart file uploads for efficiency, this uses the File Upload feature as listed at
         https://www.apollographql.com/blog/graphql/file-uploads/with-apollo-server-2-0/ given on our Ruby API by
         the https://github.com/jetruby/apollo_upload_server-ruby RubyGem.

         You can see the saveOnBeamObject and saveOnBeamObjects for code samples how to name `variableName` so it
         has precedence and is used by the server to replace the inline GraphQL query variable. Tests available at
         https://github.com/jetruby/apollo_upload_server-ruby/blob/master/spec/apollo_upload_server/graphql_data_builder_spec.rb
         give a pretty good idea how to put index in names in the format of `'0.variables.input.avatars.2'`

         Best if you can't figure it out is to first use `curl` in command line, `scripts/test_multipart_upload.sh` shows
         samples and you can read https://graphql-compose.github.io/docs/guide/file-uploads.html or
         https://dilipkumar.medium.com/graphql-and-file-upload-using-react-and-node-js-c1d629e1b86b

         see RFC1521 for multipart https://datatracker.ietf.org/doc/html/rfc1521#page-29
         see https://www.floriangaechter.com/blog/graphql-file-uploading/ for example about file uploads & GraphQL

         use https://www.requestcatcher.com to view all HTTP requests but don't include private keys! I don't know who's
         behind this service.
         */

        if let files = files, !files.isEmpty {
            let boundary = "------------------------\(UUID().uuidString)"
            let lineBreak = "\r\n"
            var queryData = Data()

            // Add the GraphQL query
            queryData.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
            queryData.append("Content-Disposition: form-data; name=\"operations\"\(lineBreak)\(lineBreak)".asData)
            queryData.append(graphqlQuery)

            var mapperDictionary: [String: [String]] = [:]

            for file in files {
                queryData.append("\(lineBreak)--\(boundary)\(lineBreak)".asData)
                queryData.append("Content-Disposition: form-data; name=\"\(file.filename)\"; filename=\"\(file.filename)\"\(lineBreak)".asData)
                queryData.append("Content-Type: \(file.contentType)\(lineBreak)\(lineBreak)".asData)
                queryData.append(file.binary) // use query.append("whatever".asData) for debug and display logs

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
        } else {
            Logger.shared.logDebug("-> HTTP Request: \(route) (can't display multipart uploads)\n",
                                   category: .network)
        }
        #endif

        return request
    }

    // If request contains a filename but no query, load the query from fileName
    func loadQuery<T: GraphqlParametersProtocol>(_ bodyParamsRequest: T) -> T {
        if bodyParamsRequest.fileName == nil && bodyParamsRequest.query == nil {
            ThirdPartyLibrariesManager.shared.nonFatalError("Missing fileName or query in GraphqlParameters")
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
            ThirdPartyLibrariesManager.shared.nonFatalError(error: error)
        }
    }

    // swiftlint:disable function_body_length
    func parseDataTask<T: Decodable & Errorable>(data: Data?,
                                                 response: URLResponse?,
                                                 error: Error?,
                                                 filename: String,
                                                 authenticatedCall: Bool? = nil,
                                                 localTimer: Date,
                                                 completionHandler: @escaping (Swift.Result<T, Error>) -> Void) {

        let callsCount = Self.callsCount

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
            // swiftlint:disable:next date_init
            let localTimer = Date()

            let value: T = try self.manageResponse(data, response)

            // swiftlint:disable:next date_init
            let diffTime = Date().timeIntervalSince(localTimer)
            if diffTime > 0.1 {
                Logger.shared.logWarning("Parsed network response (\(data?.count.byteSize ?? "-"))",
                                         category: .network,
                                         localTimer: localTimer)
            }

            self.backgroundQueue.async {
                completionHandler(.success(value))
            }
        } catch {
            Logger.shared.logError("Can't parse into \(T.self): \(data?.asString ?? "-")", category: .network)
            Logger.shared.logError(error.localizedDescription, category: .network)
            self.backgroundQueue.async {
                completionHandler(.failure(error))
            }
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

    func defaultDecoder() -> BeamJSONDecoder {
        let decoder = BeamJSONDecoder()
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
