//
//  WebSearchMessageHandler.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 19/08/2021.
//

import Foundation
import BeamCore

enum SearchMessage: String, CaseIterable {
    case SearchWebPage_webPageSearch
    case SearchWebPage_webSearchCurrentSelection
}

class WebSearchMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = SearchMessage.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "SearchWebPage_prod")
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let receivedMessage = SearchMessage(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for WebSearch message handler", category: .web)
            return
        }
        guard let searchViewModel = webPage.searchViewModel else { return }
        guard let body = messageBody as? [String: Any] else {
            searchViewModel.foundOccurences = 0
            searchViewModel.currentOccurence = 0
            return
        }

        switch receivedMessage {
        case .SearchWebPage_webPageSearch:
            if let found = body["totalResults"] as? UInt {
                searchViewModel.foundOccurences = found
            }
            if let incompleteSearch = body["incompleteSearch"] as? Bool {
                searchViewModel.incompleteSearch = incompleteSearch
            }
            if let current = body["currentResult"] as? UInt {
                searchViewModel.currentOccurence = current
            }
            if let positions = body["positions"] as? [Double] {
                searchViewModel.positions = positions
            }
            if let pageHeight = body["height"] as? Double {
                searchViewModel.pageHeight = pageHeight
            }
            if let currentPosition = body["currentSelected"] as? Double {
                searchViewModel.currentPosition = currentPosition
            }
        case .SearchWebPage_webSearchCurrentSelection:
            if let selection = body["selection"] as? String {
                searchViewModel.searchTerms = selection
            }
        }
    }
}
