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
    private var lineBreak: String { "%0D%0A" }

    func buildURL(with textParam: String, url: URL?) -> URL? {
        var urlString: String
        let encodedContent = textParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedURL = url?.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch self {
        case .copy:
            return nil
        case .twitter:
            urlString = "https://twitter.com/intent/tweet?text=\(encodedContent)&url=\(encodedURL)&via=\(twitterBeamUsername)"
        case .facebook:
            urlString = "https://www.facebook.com/dialog/share?app_id=\(facebookAppID)&display=popup&quote=\(encodedContent)&href=\(encodedURL)"
        case .linkedin:
            urlString = "https://www.linkedin.com/shareArticle?mini=true&url=\(encodedURL)&title=\(encodedContent)"
        case .reddit:
            urlString = "https://reddit.com/submit?title=\(encodedContent)&url=\(encodedURL)"
        case .email:
            urlString = "mailto:?body=\(encodedContent)\(lineBreak)\(lineBreak)\(encodedURL)"
        case .messages:
            urlString = "sms:&body=\(encodedContent)\(lineBreak)\(lineBreak)\(encodedURL)"
        }
        return URL(string: urlString)
    }

    static func allCases(except: [ShareService]) -> [ShareService] {
        allCases.filter { !except.contains($0) }
    }
}
