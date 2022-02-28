//
//  WebFrames.swift
//  Beam
//
//  Created by Frank Lefebvre on 22/02/2022.
//

import BeamCore
import Combine

final class WebFrames {
    private(set) var frames = [String: Set<String>]()
    private var subject = PassthroughSubject<String, Never>()

    var removedFrames: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }

    func setFrame(href: String, children: Set<String>, isMain: Bool) {
        Logger.shared.logDebug("WebFrames - before: \(frames)", category: .web)
        if let previousChildren = frames[href] {
            let removedChildren = previousChildren.subtracting(children)
            var framesToRemove = Set<String>()
            for href in removedChildren {
                framesToRemove.formUnion(descendents(of: href))
            }
            let keysToRemove = framesToRemove.intersection(frames.keys)
            for href in keysToRemove {
                frames[href] = nil
                subject.send(href)
            }
        }
        frames[href] = children
        if isMain {
            let framesToKeep = descendents(of: href)
            let keysToRemove = Set(frames.keys).subtracting(framesToKeep)
            for href in keysToRemove {
                frames[href] = nil
                subject.send(href)
            }
        }
        Logger.shared.logDebug("WebFrames - after: \(frames)", category: .web)
    }

    private func descendents(of href: String) -> Set<String> {
        var descendents = Set<String>()
        if let children = frames[href] {
            for href in children {
                descendents.formUnion(self.descendents(of: href))
            }
            descendents.insert(href)
        }
        return descendents
    }
}
