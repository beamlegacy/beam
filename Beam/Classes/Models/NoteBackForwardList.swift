//
//  NoteBackForwardList.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/10/2020.
//

import Foundation
import BeamCore

class NoteBackForwardList: Codable {
    enum Element: Codable, Equatable {
        case note(BeamNote)
        case page(WindowPage)
        case journal

        //swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case mode
            case note
            case page
        }

        static func == (lhs: NoteBackForwardList.Element, rhs: NoteBackForwardList.Element) -> Bool {
            switch (lhs, rhs) {
            case (.journal, .journal):
                return true
            case (.note(let lhsNote), .note(let rhsNote)):
                return lhsNote.id == rhsNote.id
            case (.page(let lhsPage), .page(let rhsPage)):
                return lhsPage.id == rhsPage.id
            default:
                return false
            }
        }

        func isNote(_ id: UUID) -> Bool {
            switch self {
            case let .note(note):
                return note.id == id
            default:
                return false
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = .journal

            switch try container.decode(Int.self, forKey: .mode) {
            case 0:
                let noteTitle = try container.decode(String.self, forKey: .note)
                if let note = BeamNote.fetch(title: noteTitle) {
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
            case .page(let page):
                try container.encode(0, forKey: .mode)
                try container.encode(page.id.rawValue, forKey: .page)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case back
        case current
        case forward
    }

    init() { }

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
        guard current != element else { return }
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

    private func purgeConsecutiveDuplicates(_ list: [Element]) -> [Element] {
        var previous: Element?
        return list.compactMap {
            guard $0 != previous else { return nil }
            previous = $0
            return $0
        }
    }

    private func purgeConsecutiveDuplicates () {
        backList = purgeConsecutiveDuplicates(backList)
        if backList.last == current {
            backList.removeLast()
        }
        forwardList = purgeConsecutiveDuplicates(forwardList)
    }

    func purgeDeletedNote(withId id: UUID) {
        backList = backList.compactMap { $0.isNote(id) ? nil : $0 }
        forwardList = forwardList.compactMap { $0.isNote(id) ? nil : $0 }
        purgeConsecutiveDuplicates()
    }

    func clear() {
        current = nil
        clearBackward()
        clearForward()
    }

    func clearForward() {
        forwardList.removeAll()
    }

    func clearBackward() {
        backList.removeAll()
    }

    private(set) var backList: [Element] = []
    private(set) var forwardList: [Element] = []
}
