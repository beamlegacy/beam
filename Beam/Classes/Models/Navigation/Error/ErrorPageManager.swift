//
//  ErrorPageManager.swift
//  Beam
//
//  Created by Florian Mari on 16/09/2021.
//

import Foundation
import Combine

class ErrorPageManager {
    enum Error: Swift.Error {
        case network, radblock, hostUnreachable, unknown
    }

    let errorCode: Int
    let webView: WKWebView
    var defaultLocalizedDescription: String?
    let errorUrl: URL

    private var cancellables = Set<AnyCancellable>()

    init(_ errorCode: Int, webView: WKWebView, errorUrl: URL, defaultLocalizedDescription: String? = nil) {
        self.errorCode = errorCode
        self.webView = webView
        self.errorUrl = errorUrl
        self.defaultLocalizedDescription = defaultLocalizedDescription
    }

    var error: Error {
        switch errorCode {
        case 104:
            return .radblock
        case NSURLErrorNotConnectedToInternet:
            return .network
        case NSURLErrorCannotFindHost:
            return .hostUnreachable
        default:
            return .unknown
        }
    }

    var domain: String {
        return errorUrl.minimizedHost ?? errorUrl.absoluteString
    }

    var title: String {
        switch error {
        case .network:
            return "No Internet Connection"
        case .radblock:
            return "Site is blocked by Beam"
        case .hostUnreachable:
            return "This site can’t be reached"
        case .unknown:
            return "Error"
        }
    }

    var primaryMessage: String {
        switch error {
        case .network:
            return "It looks like your computer is not connected"
        case .radblock:
            return "The site “\(domain)”"
        case .hostUnreachable:
            return "Beam cannot find the server for"
        case .unknown:
            return defaultLocalizedDescription ?? ""
        }
    }

    var secondaryMessage: String {
        switch error {
        case .network:
            return "to the Internet"
        case .radblock:
            return "has been blocked by Beam."
        case .hostUnreachable:
            return "“\(domain)”."
        case .unknown:
            return ""
        }
    }

    func htmlPage() -> Data {
        let file = "GenericErrorPage"
        let htmlErrorFile = Bundle.main.path(forResource: file, ofType: "html")!
        //swiftlint:disable:next force_try
        let htmlErrorPage = try! String(contentsOfFile: htmlErrorFile)
            .replacingOccurrences(of: "%errorTitle%", with: title)
        return htmlErrorPage.data(using: .utf8)!
    }

    func loadPage(for url: URL) {
        guard var components = URLComponents(string: "\(BeamURL.baseUrl)/\(LocalPageSchemeHandler.path)") else {
            return
        }

        var queryItems = [
            URLQueryItem(name: BeamURL.Param.url.rawValue, value: url.absoluteString),
            URLQueryItem(name: "code", value: String(errorCode)),
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "errorTitle", value: title)
        ]

        if let localizedDescription = defaultLocalizedDescription {
            queryItems.append(URLQueryItem(name: "localizedDescription", value: localizedDescription))
        }

        components.queryItems = queryItems
        if let urlWithQuery = components.url {
            // A new page needs to be added to the history stack (i.e. the simple case of trying to navigate to an url for the first time and it fails, without pushing a page on the history stack, the webview will just show the current page).
            webView.load(URLRequest(url: urlWithQuery))
        }
    }

    func permanentlyAuthorize(completion: @escaping () -> Void) {
        guard error == .radblock else { return }

        ContentBlockingManager.shared.radBlockPreferences.add(domain: domain)
        ContentBlockingManager.shared.configure(webView: webView)
        NotificationCenter.default
            .publisher(for: .RBDatabaseDidAddEntry)
            .sink { [authorizeJustOnce] _ in
                // Cause Radblock is very async and doesn't notify when all db are synchronized, we remove rules to get a fast-ui response
                authorizeJustOnce {
                    completion()
                }
            }
            .store(in: &cancellables)
    }

    func authorizeJustOnce(completion: @escaping () -> Void) {
        ContentBlockingManager.shared.authorizeJustOnce(for: webView, domain: domain) {
            completion()
        }
    }
}

class LocalPageSchemeHandler: BeamSchemeHandlerResponse {

    static let path = BeamURL.Path.errorpage.rawValue

    func response(request: URLRequest) -> (URLResponse, Data)? {
        guard let requestUrl = request.url, let originalUrl = BeamURL(requestUrl).originalURLFromErrorPage else {
            return nil
        }
        let asset = Bundle.main.path(forResource: "GenericErrorPage", ofType: "html")

        guard let file = asset, var html = try? String(contentsOfFile: file) else {
            assert(false)
            return nil
        }

        let response = BeamSchemeHandler.response(forUrl: originalUrl)
        html = html.replacingOccurrences(of: "%errorTitle%", with: BeamURL.getQueryStringParameter(url: requestUrl.absoluteString, param: "errorTitle")!)
        guard let data = html.data(using: .utf8) else { return nil }
        return (response, data)
    }
}
