//
//  NoteBackForwardList.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/10/2020.
//

import Foundation

class NoteBackForwardList {
    enum Element {
        case note(Note)
        case journal
    }

    func push(_ element: Element) {
        if let n = current {
            backList.append(n)
        }

        current = element
        forwardList = []

    }

    func goBack() -> Element? {
        guard let back = backList.popLast() else { return nil }
        if let n = current {
            forwardList.append(n)
        }

        current = back

        return back
    }

    func goForward() -> Element? {
        guard let forward = forwardList.popLast() else { return nil }
        if let n = current {
            backList.append(n)
        }

        current = forward

        return forward
    }

    private(set) var current: Element?

    func note(at index: Int) -> Element? {
        if index == 0 {
            return current
        }

        if index < 0 {
            let i = backList.count + index
            if i < 0 {
                return nil
            }

            return backList[i]
        }

        if index < forwardList.count {
            return forwardList[index]
        }

        return nil

    }

    private(set) var backList: [Element] = []
    private(set) var forwardList: [Element] = []
}
