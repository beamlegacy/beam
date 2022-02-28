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
    private var classifiersByFrame: [String: WebAutocompleteContext] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(webFrames: WebFrames) {
        webFrames.removedFrames.sink { href in
            self.classifiersByFrame[href] = nil
        }
        .store(in: &cancellables)
    }

    private init() {}

    func clear() {
        classifiersByFrame.removeAll()
    }

    func classify(fields: [DOMInputElement], host: String?, frameInfo: WKFrameInfo?) -> [String] {
        guard let frameHref = frameInfo?.request.url?.absoluteString else {
            return []
        }
        let classifier = classifiersByFrame[frameHref] ?? WebAutocompleteContext()
        classifiersByFrame[frameHref] = classifier
        return classifier.update(with: fields, on: host)
    }

    func autocompleteGroup(for elementId: String, frameInfo: WKFrameInfo?) -> WebAutocompleteGroup? {
        guard let frameHref = frameInfo?.request.url?.absoluteString, let classifier = classifiersByFrame[frameHref] else {
            Logger.shared.logWarning("No classifier for input element \(elementId)", category: .passwordManager)
            return nil
        }
        return classifier.autocompleteGroup(for: elementId)
    }

    func allInputFields(frameInfo: WKFrameInfo?) -> [WebInputField] {
        guard let frameHref = frameInfo?.request.url?.absoluteString, let classifier = classifiersByFrame[frameHref] else {
            return []
        }
        return classifier.allInputFields
    }

    func allInputFieldIds(frameInfo: WKFrameInfo?) -> [String] { // no order constraint
        Array(Set(allInputFields(frameInfo: frameInfo).map(\.id)))
    }
}
