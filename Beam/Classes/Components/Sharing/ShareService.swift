//
//  ShareService.swift
//  Beam
//
//  Created by Remi Santos on 13/04/2022.
//

import Foundation
import BeamCore

enum ShareService: CaseIterable {
    // social
    case twitter
    case facebook
    case linkedin
    case reddit
    // os
    case copy
    case email
    case messages

    var title: String {
        switch self {
        case .twitter:
            return "Twitter"
        case .facebook:
            return "Facebook"
        case .linkedin:
            return "LinkedIn"
        case .reddit:
            return "Reddit"
        case .copy:
            return "Copy"
        case .email:
            return "Email"
        case .messages:
            return "Messages"
        }
    }

    var icon: String {
        switch self {
        case .twitter:
            return "social-twitter_fill"
        case .facebook:
            return "social-facebook_fill"
        case .linkedin:
            return "social-linkedin_fill"
        case .reddit:
            return "social-reddit_fill"
        case .copy:
            return "editor-url_copy_16"
        case .email:
            return "social-mail_fill"
        case .messages:
            return "social-message_fill"
        }
    }

    private var twitterBeamUsername: String { "getonbeam" }
    private var facebookAppID: String { EnvironmentVariables.Oauth.Facebook.appID }

    func buildURL(with textParam: String?, url: URL?) -> URL? {
        var baseURLString: String
        var urlText: String?
        if let absoluteURLString = url?.absoluteString, absoluteURLString.mayBeWebURL {
            urlText = absoluteURLString
        }
        var queryItems: [String: String?] = [:]
        switch self {
        case .copy:
            return nil
        case .twitter:
            baseURLString = "https://twitter.com/intent/tweet"
            queryItems = ["via": twitterBeamUsername, "url": urlText, "text": textParam]
        case .facebook:
            baseURLString = "https://www.facebook.com/dialog/share"
            queryItems = ["app_id": facebookAppID, "display": "popup", "quote": textParam]
            queryItems["href"] = urlText ?? "beamapp.co" // facebook requires a href
        case .linkedin:
            baseURLString = "https://www.linkedin.com/shareArticle"
            queryItems = ["mini": "true", "url": urlText, "title": textParam]
        case .reddit:
            baseURLString = "https://reddit.com/submit"
            queryItems = ["url": urlText, "title": textParam]
        case .email:
            baseURLString = "mailto:"
            var body = textParam ?? ""
            if let urlText = urlText, !urlText.isEmpty {
                body = "\(body)\(!body.isEmpty ? "\n\n" : "")\(urlText)"
            }
            queryItems["body"] = body
        case .messages:
            baseURLString = "sms:"
            var body = textParam ?? ""
            if let urlText = urlText, !urlText.isEmpty {
                body = "\(body)\(!body.isEmpty ? "\n\n" : "")\(urlText)"
            }
            queryItems["app"] = "beam" // not gonna appear, but somehow sms body doesn't work if it's the first query item
            queryItems["body"] = body
        }

        var components = URLComponents(string: baseURLString)
        components?.queryItems = dictionnaryToURLQueryItems(queryItems)
        return components?.url
    }

    private func dictionnaryToURLQueryItems(_ dic: [String: String?]) -> [URLQueryItem] {
        var items = [URLQueryItem]()
        dic.forEach { key, value in
            items.append(URLQueryItem(name: key, value: value))
        }
        return items
    }

    static func allCases(except: [ShareService]) -> [ShareService] {
        allCases.filter { !except.contains($0) }
    }
}
