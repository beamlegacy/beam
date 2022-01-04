//
//  EmbedContent.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation

enum ResponsiveType: String {
    case horizontal
    case vertical
    case both
}

struct EmbedContent: Equatable {
    /// oEmbed compliant media type
    enum MediaType: String {
        @available(*, deprecated, message: "Use link instead")
        case url
        @available(*, deprecated, message: "Use photo instead")
        case image
        @available(*, deprecated, message: "Use rich instead")
        case page
        @available(*, deprecated, message: "Use rich instead")
        case audio

        case video
        case photo
        case link
        // aka: HTML string to be embedded in WebView
        case rich
    }
    // Title of page where the original content was found, likely improved with OpenGraph or
    // twitter meta information. If no useful title can be found it defaults to sourceURL
    var title: String
    // Type of embedded content, used to determine display strategy
    var type: MediaType
    // URL where the original content can be found
    var sourceURL: URL
    // URL used for displaying embedded content
    var embedURL: URL?
    // HTML content used for embedding in WebView
    var html: String?
    // URL to thumbnail image, usually the favicon of the embed service
    var thumbnail: URL?
    // Original width as provided by the Embed API
    var width: CGFloat?
    // Original heigth as provided by the Embed API
    var height: CGFloat?

    var minWidth: CGFloat?
    var maxWidth: CGFloat?
    var minHeight: CGFloat?
    var maxHeight: CGFloat?
    var keepAspectRatio: Bool = true
    var responsive: ResponsiveType = .both
}
