//
//  NoteBackForwardList.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/10/2020.
//

import Foundation

class NoteBackForwardList {
    func push(note: Note) {
        if let n = currentNote {
            backList.append(n)
        }

        currentNote = note
        forwardList = []
    }

    func goBack() -> Note? {
        guard let back = backList.popLast() else { return nil }
        if let n = currentNote {
            forwardList.append(n)
        }

        currentNote = back

        return back
    }

    func goForward() -> Note? {
        guard let forward = forwardList.popLast() else { return nil }
        if let n = currentNote {
            backList.append(n)
        }

        currentNote = forward

        return forward
    }

    private(set) var currentNote: Note?
    var backNote: Note? { backList.last }
    var forwardNote: Note? { forwardList.last }

    func note(at index: Int) -> Note? {
        if index == 0 {
            return currentNote
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

    private(set) var backList: [Note] = []
    private(set) var forwardList: [Note] = []
}
