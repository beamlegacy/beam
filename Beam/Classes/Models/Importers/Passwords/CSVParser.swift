//
//  CSVParser.swift
//
//  RFC4180-compliant CSV parser.
//  Created by Frank Lefebvre on 10/07/2021.
//

enum CharacterEvent: Equatable {
    case character(Character)
    case fieldSeparator
    case recordSeparator
    case skip
}

struct CSVUnescapingSequence<Input: Sequence>: Sequence, IteratorProtocol where Input.Element == Character {
    typealias Element = CharacterEvent

    enum State {
        case lineStart
        case fieldStart
        case unquoted
        case quoted
        case escaping
    }

    let fieldSeparator: Character = ","
    let lineFeed: Character = "\n"
    let carriageReturn: Character = "\r"
    let crlf: Character = "\r\n"
    let quote: Character = "\""

    private var inputIterator: Input.Iterator
    private var state = State.lineStart

    init(input: Input) {
        inputIterator = input.makeIterator()
    }

    mutating func next() -> CharacterEvent? {
        var event: CharacterEvent?
        repeat {
            guard let character = inputIterator.next() else { return nil }
            event = handleNext(character)
        } while event == .skip
        return event
    }

    private mutating func handleNext(_ character: Character) -> CharacterEvent {
        switch state {
        case .lineStart:
            return handleCharacterInLineStartState(character)
        case .fieldStart:
            return handleCharacterInFieldStartState(character)
        case .unquoted:
            return handleCharacterInUnquotedState(character)
        case .quoted:
            return handleCharacterInQuotedState(character)
        case .escaping:
            return handleCharacterInEscapingState(character)
        }
    }

    private mutating func handleCharacterInLineStartState(_ character: Character) -> CharacterEvent {
        switch character {
        case fieldSeparator:
            return .fieldSeparator
        case carriageReturn, lineFeed, crlf:
            return .skip
        case quote:
            state = .quoted
            return .skip
        default:
            state = .unquoted
            return .character(character)
        }
    }

    private mutating func handleCharacterInFieldStartState(_ character: Character) -> CharacterEvent {
        switch character {
        case fieldSeparator:
            return .fieldSeparator
        case carriageReturn, lineFeed, crlf:
            state = .lineStart
            return .recordSeparator
        case quote:
            state = .quoted
            return .skip
        default:
            state = .unquoted
            return .character(character)
        }
    }

    private mutating func handleCharacterInUnquotedState(_ character: Character) -> CharacterEvent {
        switch character {
        case fieldSeparator:
            state = .fieldStart
            return .fieldSeparator
        case carriageReturn, lineFeed, crlf:
            state = .lineStart
            return .recordSeparator
        default:
            return .character(character)
        }
    }

    private mutating func handleCharacterInQuotedState(_ character: Character) -> CharacterEvent {
        switch character {
        case quote:
            state = .escaping
            return .skip
        default:
            return .character(character)
        }
    }

    private mutating func handleCharacterInEscapingState(_ character: Character) -> CharacterEvent {
        switch character {
        case fieldSeparator:
            state = .fieldStart
            return .fieldSeparator
        case carriageReturn, lineFeed, crlf:
            state = .lineStart
            return .recordSeparator
        case quote:
            state = .quoted
            return .character(character)
        default:
            state = .unquoted
            return .character(character)
        }
    }
}

struct CSVParser<Input: Sequence>: Sequence, IteratorProtocol where Input.Element == CharacterEvent {
    enum State {
        case recordStart
        case fieldStart
        case fieldData
        case end
    }

    private var inputIterator: Input.Iterator
    private var state = State.recordStart
    private var fields = [String]()
    private var currentField = ""

    init(input: Input) {
        inputIterator = input.makeIterator()
    }

    mutating func next() -> [String]? {
        while handleEvent(inputIterator.next()) {}
        if fields.isEmpty && state == .end {
            return nil
        }
        defer {
            fields = []
        }
        return fields
    }

    private mutating func handleEvent(_ event: CharacterEvent?) -> Bool {
        switch state {
        case .recordStart:
            return handleEventAtRecordStart(event)
        case .fieldStart:
            return handleEventAtFieldStart(event)
        case .fieldData:
            return handleEventAtFieldData(event)
        case .end:
            return false
        }
    }

    private mutating func handleEventAtRecordStart(_ event: CharacterEvent?) -> Bool {
        switch event {
        case nil:
            state = .end
            return false
        case .character(let character):
            currentField = String(character)
            state = .fieldData
            return true
        case .fieldSeparator:
            currentField = ""
            fields.append(currentField)
            state = .fieldStart
            return true
        case .recordSeparator:
            return true
        case .skip:
            fatalError()
        }
    }

    private mutating func handleEventAtFieldStart(_ event: CharacterEvent?) -> Bool {
        switch event {
        case nil:
            state = .end
            return false
        case .character(let character):
            currentField = String(character)
            state = .fieldData
            return true
        case .fieldSeparator:
            currentField = ""
            fields.append(currentField)
            return true
        case .recordSeparator:
            currentField = ""
            fields.append(currentField)
            state = .recordStart
            return false
        case .skip:
            fatalError()
        }
    }

    private mutating func handleEventAtFieldData(_ event: CharacterEvent?) -> Bool {
        switch event {
        case nil:
            fields.append(currentField)
            currentField = ""
            state = .end
            return false
        case .character(let character):
            currentField.append(character)
            return true
        case .fieldSeparator:
            fields.append(currentField)
            currentField = ""
            state = .fieldStart
            return true
        case .recordSeparator:
            fields.append(currentField)
            currentField = ""
            state = .recordStart
            return false
        case .skip:
            fatalError()
        }
    }
}
