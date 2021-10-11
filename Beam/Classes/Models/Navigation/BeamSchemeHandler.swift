//
//  BeamSchemeHandler.swift
//  Beam
//
//  Created by Florian Mari on 01/10/2021.
//

import Foundation

struct BeamURL {
    let url: URL

    static let uuid = UUID().uuidString
    static let scheme = "beam"
    static let baseUrl = "\(scheme)://local"

    enum Path: String {
        case errorpage
        func matches(_ string: String) -> Bool {
            return string.range(of: "/?\(self.rawValue)", options: .regularExpression, range: nil, locale: nil) != nil
        }
    }

    enum Param: String {
        case url
        func matches(_ string: String) -> Bool { return string == self.rawValue }
    }

    init(_ url: URL) {
        self.url = url
    }

    var isErrorPage: Bool {
        return url.absoluteString.contains(BeamURL.baseUrl + "/" + BeamURL.Path.errorpage.rawValue)
    }

    var originalURLFromErrorPage: URL? {
        if let urlParam = BeamURL.getQueryStringParameter(url: url.absoluteString, param: "url") {
            return URL(string: urlParam)
        }
        return nil
    }

    static func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
}

protocol BeamSchemeHandlerResponse {
    func response(request: URLRequest) -> (URLResponse, Data)?
}

enum BeamSchemeHandlerError: Error {
    case badUrl
    case noResponder
    case responderUnableToHandle
}

class BeamSchemeHandler: NSObject, WKURLSchemeHandler {

    static func response(forUrl url: URL) -> URLResponse {
        return URLResponse(url: url, mimeType: "text/html", expectedContentLength: -1, textEncodingName: "utf-8")
    }

    // Example responder ["licences/opensource"] leads to "beam://licences/opensource"
    static var responders = [String: BeamSchemeHandlerResponse]()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(BeamSchemeHandlerError.badUrl)
            return
        }

        let path = url.path.starts(with: "/") ? String(url.path.dropFirst()) : url.path

        guard let responder = BeamSchemeHandler.responders[path] else {
            urlSchemeTask.didFailWithError(BeamSchemeHandlerError.noResponder)
            return
        }

        guard let (urlResponse, data) = responder.response(request: urlSchemeTask.request) else {
            urlSchemeTask.didFailWithError(BeamSchemeHandlerError.responderUnableToHandle)
            return
        }

        urlSchemeTask.didReceive(urlResponse)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { }
}
