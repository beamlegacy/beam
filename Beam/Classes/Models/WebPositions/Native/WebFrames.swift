//
//  WebFrames.swift
//  Beam
//
//  Created by Frank Lefebvre on 22/02/2022.
//

import BeamCore
import Combine

final class WebFrames: ObservableObject {
    typealias HREF = String
    typealias ParentHREF = String

    struct FrameInfo {
        var href: HREF
        var parentHref: ParentHREF
        var x: CGFloat = 0
        var y: CGFloat = 0
        var scrollX: CGFloat = 0
        var scrollY: CGFloat = 0
        var width: CGFloat = -1
        var height: CGFloat = -1
        var isMain: Bool = false
    }

    /// Frame info by frame HREF
    @Published var framesInfo = [HREF: FrameInfo]()

    /// Children HREFs by parent HREF
    private(set) var hrefTree = [ParentHREF: Set<HREF>]()

    private var removedFrameSubject = PassthroughSubject<String, Never>()

    var removedFrames: AnyPublisher<HREF, Never> {
        removedFrameSubject.eraseToAnyPublisher()
    }

    func setFrames(_ frames: [FrameInfo], isMain: Bool) {
        let frames = frames.filter { !$0.href.isEmpty }
        guard let parent = frames.first(where: { !$0.hasParentFrame }) else {
            Logger.shared.logError("WebFrames received \(frames.count) frames with no parent", category: .web)
            return
        }
        let parentHref = parent.href
        let childrenHrefs = Set(frames.filter(\.hasParentFrame).map(\.href))

        for frame in frames {
            if frame.hasParentFrame || framesInfo[frame.href] == nil || !isConnectedToMain(href: frame.href) {
                framesInfo[frame.href] = frame
            } else {
                Logger.shared.logDebug("Ignoring frameInfo for \(frame)", category: .web)
            }
        }

        var candidatesForRemoval: Set<HREF>
        if let previousChildren = hrefTree[parentHref] {
            let removedChildren = previousChildren.subtracting(childrenHrefs)
            var framesToRemove = Set<String>()
            for href in removedChildren {
                framesToRemove.formUnion(descendents(of: href))
            }
            candidatesForRemoval = framesToRemove.intersection(hrefTree.keys)
        } else {
            candidatesForRemoval = []
        }
        hrefTree[parentHref] = childrenHrefs
        if isMain {
            let framesToKeep = descendents(of: parentHref)
            candidatesForRemoval.formUnion(Set(hrefTree.keys).subtracting(framesToKeep))
        }

        let reconnected = reconnectedFrames()
        for (href, parentHref) in reconnected {
            hrefTree[parentHref] = (hrefTree[parentHref] ?? []).union([href])
            framesInfo[href]?.parentHref = parentHref
            candidatesForRemoval.remove(href)
            candidatesForRemoval.subtract(descendents(of: href))
        }

        for href in candidatesForRemoval {
            Logger.shared.logDebug("Removing from frame tree: \(href)", category: .web)
            hrefTree[href] = nil
            framesInfo[href] = nil
            removedFrameSubject.send(href)
        }
    }

    func isConnectedToMain(href: HREF) -> Bool {
        let PATH_LIMIT = 10
        var href = href
        var pathLength = 0
        while pathLength < PATH_LIMIT, let frame = framesInfo[href] {
            pathLength += 1
            if frame.hasParentFrame {
                href = frame.parentHref
            } else {
                return frame.isMain
            }
        }
        return false
    }

    /// Recursively generate a subset of the framesInfo dictionary with all frames from the requested frame to the root frame
    /// - Parameters:
    ///   - href: url of frame
    /// - Returns: Dictionary, possibly empty if the requested url was not found
    func framesInPath(href: HREF, childFrames: [HREF: FrameInfo] = [:], depth: Int = 0) -> [HREF: FrameInfo] {
        // Limit recursion to a depth of 10
        let DEPTH_LIMIT = 10
        // by default allPositions starts as empty array []
        // reassign allPositions to mutable value
        var frames = childFrames
        // get full frameInfo from framesInfo dict
        guard let frame = framesInfo[href] else {
            return frames
        }
        frames[frame.href] = frame
        // If we aren't on the root frame, and we are below the depth recursion limit
        if frame.hasParentFrame, depth < DEPTH_LIMIT {
            // run this function recursively
            return framesInPath(href: frame.parentHref, childFrames: frames, depth: depth + 1)
        }
        return frames
    }

    func dumpFrames() {
        for frame in framesInfo {
            Logger.shared.logDebug("Dump frame: \(frame.value) (key = \(frame.key))", category: .web)
        }
        for elem in hrefTree {
            Logger.shared.logDebug("Dump tree: \(elem.key) -> \(elem.value)", category: .web)
        }
    }

    /// Local leaves: frames with no children
    private var leafFrames: [FrameInfo] {
        let parentHrefs = Set(framesInfo.values.map(\.parentHref))
        let leafHrefs = Set(framesInfo.keys).subtracting(parentHrefs).filter { !$0.isEmpty }
        return leafHrefs.compactMap { framesInfo[$0] }
    }

    /// Lost frames: frames disconnected from the tree (neither main nor direct children of another frame)
    private var lostFrames: [FrameInfo] {
        framesInfo.values.filter { !$0.isMain && !$0.hasParentFrame }
    }

    /// Lost frames to be reconnected to the tree
    private func reconnectedFrames() -> [HREF: ParentHREF] {
        let lost = lostFrames
        guard !lost.isEmpty else { return [:] }
        var reconnected = [HREF: ParentHREF]()
        let candidates = leafFrames
        for frame in lostFrames {
            guard frame.width != 0, frame.height != 0 else { continue }
            let candidatesMatchingSize = candidates.filter { $0.width == frame.width && $0.height == frame.height }
            if candidatesMatchingSize.count == 1 {
                reconnected[frame.href] = candidatesMatchingSize[0].href
            }
        }
        return reconnected
    }

    private func descendents(of href: String) -> Set<String> {
        var descendents = Set<String>()
        if let children = hrefTree[href] {
            for href in children {
                descendents.formUnion(self.descendents(of: href))
            }
            descendents.insert(href)
        }
        return descendents
    }
}

extension WebFrames.FrameInfo {
    var hasParentFrame: Bool {
        guard !href.isEmpty, !parentHref.isEmpty else {
            return false
        }
        return href != parentHref
    }
}
