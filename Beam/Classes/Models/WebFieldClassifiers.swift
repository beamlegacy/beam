//
//  WebFieldClassifiers.swift
//  Beam
//
//  Created by Frank Lefebvre on 23/02/2022.
//

import Foundation
import Combine
import BeamCore

final class WebFieldClassifiers {
    private var classifier: WebFieldClassifier
    private var classifierResultsByFrame: [String: WebFieldClassifier.ClassifierResult] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(webFrames: WebFrames) {
        classifier = WebFieldClassifier()
        webFrames.removedFrames.sink { href in
            Logger.shared.logDebug("Removing classifier for frame \(href)", category: .passwordManagerInternal)
            self.classifierResultsByFrame[href] = nil
        }
        .store(in: &cancellables)
    }

    private init() {
        fatalError()
    }

    func clear() {
        classifierResultsByFrame.removeAll()
    }

    @discardableResult
    func classify(fields: [DOMInputElement], host: String?, frameInfo: WKFrameInfo?) -> [String] {
        guard let frameHref = frameInfo?.request.url?.absoluteString else {
            return []
        }
        let result = classifier.classify(rawFields: fields, on: host)
        classifierResultsByFrame[frameHref] = result
        return result.activeFields
    }

    func autocompleteGroup(for elementId: String, frameInfo: WKFrameInfo?) -> WebAutocompleteGroup? {
        guard let frameHref = frameInfo?.request.url?.absoluteString else {
            Logger.shared.logWarning("No classifier for input element \(elementId) in frame \(frameInfo?.request.url?.absoluteString ?? "nil")", category: .passwordManager)
            return nil
        }
        return classifierResultsByFrame[frameHref]?.autocompleteGroups[elementId]
    }

    func allInputFields(frameInfo: WKFrameInfo?) -> [WebInputField] {
        guard let frameHref = frameInfo?.request.url?.absoluteString else {
            return []
        }
        return classifierResultsByFrame[frameHref]?.allInputFields ?? []
    }

    func allInputFieldIds(frameInfo: WKFrameInfo?) -> [String] { // no order constraint
        Array(Set(allInputFields(frameInfo: frameInfo).map(\.id)))
    }
}
