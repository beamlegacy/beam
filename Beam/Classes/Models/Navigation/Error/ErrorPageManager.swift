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

    let wkError: NSError
    let webView: WKWebView

    private var cancellables = Set<AnyCancellable>()

    init(_ wkError: NSError, webView: WKWebView) {
        self.wkError = wkError
        self.webView = webView
    }

    var error: Error {
        switch wkError.code {
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
        guard let errorUrl = wkError.userInfo[NSURLErrorFailingURLErrorKey] as? URL else { return "" }
        return errorUrl.minimizedHost ?? errorUrl.absoluteString
    }

    var defaultLocalizedError: String {
        wkError.localizedDescription
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
            return defaultLocalizedError
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
