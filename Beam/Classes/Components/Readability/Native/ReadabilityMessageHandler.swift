//
//  ReadabilityMessageHandler.swift
//  Beam
//
// swiftlint:disable type_name

import Foundation
import BeamCore

import Foundation
import BeamCore

/**
 Handles logging messages sent from web page's javascript.
 */
class ReadabilityMessageHandler: SimpleBeamMessageHandler {

    init() {
        super.init(messages: [], jsFileName: "Readability_prod", jsCodePosition: .atDocumentStart)
    }

    override func onMessage(messageName: String, messageBody: Any?, from: WebPage, frameInfo: WKFrameInfo?) {}
}
