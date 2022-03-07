import BeamCore
import Foundation
import Vinyl

enum BeamAPIRestPath: String {
    case fetchAll
    case deleteAll
}

enum APIRequestMethod {
    case get
    case post
    case delete
}

extension APIRequest {
    @discardableResult
    //swiftlint:disable:next function_body_length
    func performRestRequest<T: Decodable & Errorable, C: Codable>(path: BeamAPIRestPath,
                                                                  httpMethod: APIRequestMethod = .post,
                                                                  queryParams: [[String: String]]? = nil,
                                                                  postParams: C? = nil,
                                                                  authenticatedCall: Bool? = nil,
                                                                  completionHandler: @escaping (Result<T, Error>) -> Void) throws -> Foundation.URLSessionDataTask {
        let path: String = {
            switch path {
            case .fetchAll:
                return "/api/v1/beam_objects/fetch_all"
            case .deleteAll:
                return "/api/v1/beam_objects/delete_all"
            }
        }()

        let request = try makeRestUrlRequest(path: path,
                                             httpMethod: httpMethod,
                                             queryParams: queryParams,
                                             postParams: postParams,
                                             authenticatedCall: authenticatedCall)
        let filename = "rest call: \(path)"
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

        if Configuration.env == .test, !BeamURLSession.shouldNotBeVinyled, !(BeamURLSession.shared is Turntable) {
            fatalError("All network calls must be caught by Vinyl in test environment. \(filename) was called.")
        }

        let localTimer = BeamDate.now

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

    // swiftlint:disable function_body_length cyclomatic_complexity
    func makeRestUrlRequest<C: Codable>(path: String,
                                        httpMethod: APIRequestMethod = .get,
                                        queryParams: [[String: String]]? = nil,
                                        postParams: C? = nil,
                                        authenticatedCall: Bool?) throws -> URLRequest {
        let fullLink = "\(Configuration.apiHostname)\(path)"
        var request: URLRequest

        var headers: [String: String] = [
            "Device": Self.deviceId.uuidString.lowercased(),
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
            "Accept": "application/json",
            "Accept-Language": Locale.current.languageCode ?? "en",
//            "Accept-Encoding": "gzip, deflate, br"
        ]

        switch httpMethod {
        case .get:
            guard let urlComponents = NSURLComponents(string: fullLink) else { fatalError("Can't get URL") }
            if let queryParams = queryParams {
                urlComponents.queryItems = queryParams.flatMap { param in
                    param.map { (key, value) in
                        URLQueryItem(name: key, value: value)
                    }
                }
            }

            guard let url = urlComponents.url else { fatalError("Can't get URL") }

            request = URLRequest(url: url)
            request.httpMethod = "GET"
        case .post:
            guard let url = URL(string: fullLink) else { fatalError("Can't get URL") }
            request = URLRequest(url: url)
            if let postParams = postParams {
                let jsonData = try JSONEncoder().encode(postParams)
                request.httpBody = jsonData
                headers["Content-Type"] = "application/json"
            }
            request.httpMethod = "POST"
        case .delete:
            guard let url = URL(string: fullLink) else { fatalError("Can't get URL") }
            request = URLRequest(url: url)
            if let postParams = postParams {
                let jsonData = try JSONEncoder().encode(postParams)
                request.httpBody = jsonData
                headers["Content-Type"] = "application/json"
            }
            request.httpMethod = "DELETE"
        }

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

        #if DEBUG_API_1
        if let queryDataString = request.httpBody?.asString {
            Logger.shared.logDebug("-> HTTP Request: \(fullLink)\n\(queryDataString.replacingOccurrences(of: "\\n", with: "\n"))",
                                   category: .network)
        }
        #endif

        return request
    }
}
