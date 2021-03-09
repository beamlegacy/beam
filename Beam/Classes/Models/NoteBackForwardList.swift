//
//  NoteBackForwardList.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/10/2020.
//

import Foundation

class NoteBackForwardList: Codable {
    enum Element: Codable {
        case note(BeamNote)
        case journal

        enum CodingKeys: String, CodingKey {
            case mode
            case note
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = .journal

            switch try container.decode(Int.self, forKey: .mode) {
            case 0:
                let noteName = try container.decode(String.self, forKey: .note)
                if let note = BeamNote.fetch(AppDelegate.main.data.documentManager, title: noteName) {
                    self = .note(note)
                }
            default:
                break
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .journal:
                try container.encode(1, forKey: .mode)
            case .note(let note):
                try container.encode(0, forKey: .mode)
                try container.encode(note.title, forKey: .note)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case back
        case current
        case forward
    }

    init() {
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backList = try container.decode([Element].self, forKey: .back)
        forwardList = try container.decode([Element].self, forKey: .forward)
        current = try? container.decode(Element.self, forKey: .current)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(backList, forKey: .back)
        try container.encode(forwardList, forKey: .forward)
        if let current = current {
            try container.encode(current, forKey: .current)
        }
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
