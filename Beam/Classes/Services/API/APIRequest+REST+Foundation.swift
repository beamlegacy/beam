import BeamCore
import Foundation
import Vinyl

enum BeamAPIRestPath: String {
    case checksums
}

extension APIRequest {
    @discardableResult
    //swiftlint:disable:next function_body_length
    func performRestRequest<T: Decodable & Errorable>(path: BeamAPIRestPath,
                                                      queryParams: [String: String]? = nil,
                                                      authenticatedCall: Bool? = nil,
                                                      completionHandler: @escaping (Result<T, Error>) -> Void) throws -> Foundation.URLSessionDataTask {
        let path: String = {
            switch path {
            case .checksums:
                return "/api/v1/beam_objects/checksums"
            }
        }()

        let request = try makeRestUrlRequest(path: path, queryParams: queryParams, authenticatedCall: authenticatedCall)
        let filename = "rest call"
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

        dataTask = BeamURLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            self.parseDataTask(data: data,
                               response: response,
                               error: error,
                               filename: filename,
                               authenticatedCall: authenticatedCall,
                               completionHandler: completionHandler)
        }

        dataTask?.resume()
        if self.cancelRequest { dataTask?.cancel() }

        return dataTask!
    }

    func makeRestUrlRequest(path: String,
                            httpMethod: String = "GET",
                            queryParams: [String: String]? = nil,
                            authenticatedCall: Bool?) throws -> URLRequest {
        let fullLink = "\(Configuration.apiHostname)\(path)"

        guard let urlComponents = NSURLComponents(string: fullLink) else { fatalError("Can't get URL") }
        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { (key, value) in
                URLQueryItem(name: key, value: value)
            }
        }

        guard let url = urlComponents.url else { fatalError("Can't get URL") }

//        guard let url = URL(string: fullLink) else { fatalError("Can't get URL") }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "Device": Self.deviceId.uuidString.lowercased(),
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
            "Accept": "application/json",
            "Accept-Language": Locale.current.languageCode ?? "en"
        ]

        request.httpMethod = httpMethod
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
            Logger.shared.logDebug("-> HTTP Request: \(url)\n\(queryDataString.replacingOccurrences(of: "\\n", with: "\n"))",
                                   category: .network)
        }
        #endif

        return request
    }
}
