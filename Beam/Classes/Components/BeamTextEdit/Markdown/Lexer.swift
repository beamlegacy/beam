class Lexer {
    enum TokenType: String, Codable {
        case EndOfFile
        case Text

        case Quote
        case ExclamationMark

        case Emphasis
        case Strong

        case LinkStart
        case LinkEnd

        case OpenParent
        case CloseParent
        case OpenBracket
        case CloseBracket
        case OpenSBracket
        case CloseSBracket
        case Hash
        case CheckStart
        case CheckFilled

        case Blank

        case NewLine
    }

    struct Token: Codable {
        /// the recognized type of the token
        var type: TokenType
        /// The textual value of the token
        var string: String
        /// The position of the token in the original input string
        var start: Int = 0
        var line: Int = 0
        var column: Int = 0

        var end: Int {
            start + string.count
        }

        var typeName: String {
            return type.rawValue
        }

        init(type: TokenType, string: String) {
            self.type = type
            self.string = string
        }

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case string
            case start
            case line
            case column
        }
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            type = try container.decode(TokenType.self, forKey: .type)
            string = try container.decode(String.self, forKey: .string)
            start = try container.decode(Int.self, forKey: .start)
            line = try container.decode(Int.self, forKey: .line)
            column = try container.decode(Int.self, forKey: .column)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(type, forKey: .type)
            try container.encode(string, forKey: .string)
            try container.encode(start, forKey: .start)
            try container.encode(line, forKey: .line)
            try container.encode(column, forKey: .column)
        }

    }

    let input: String
    var start: String.Index
    var end: String.Index
    var token = Token(type: .EndOfFile, string: "")
    var lastChar: Character = "\0"
    var char: Character = "\0"

    var line: Int = 0
    var column: Int = 0
    var tokenLine: Int = 0
    var tokenColumn: Int = 0

    var blanks: Set<Character> = []

    init(inputString: String) {
        input = inputString
        start = input.startIndex
        end = start
        createTokenPatterns()
        if input.isEmpty {
            isFinished = true
        }
        // Start streaming chars:
        _ = nextChar()

    }

    func nextNonBlankToken(_ skipNewLinesToo: Bool ) -> Token {
        repeat {
            _ = nextToken()
        } while (((token.type == .Blank) || (skipNewLinesToo ? token.type == .NewLine: true)) && !isStarved)
        return token
    }

    func nextToken() -> Token {
        token.string = ""
        token.type = .Text

        if isDone {
            return captureToken(.EndOfFile)
        }

        if char == "\u{0A}" {
            _ = nextChar()
            return captureToken(.NewLine)
        }

        if isBlank(char) {
            _ = skipBlank()
            if input.index(after: start) < end {
                return captureToken(.Blank)
            }
        }

        var pattern = patterns
        var it = pattern.children[char]
        if it != nil {
            while it != nil {
                _ = nextChar()
                pattern = it!
                it = pattern.children[char]
            }

            return captureToken(pattern.type)
        }

        var n = input.count + 1
        while !isBlank(char)
                && pattern.children[char] == nil
                && char != "\u{0A}"
                && !isFinished {
            _ = nextChar()
            n -= 1
            guard n > 0 else {
                fatalError("Lexer Error: probable infinite loop")
            }
        }
        return captureToken(.Text)
    }

    func skipBlank() -> Bool {
        while isBlank(char) && nextChar() && !isStarved {
            // Woké
        }

        return !isDone
    }

    func nextChar() -> Bool {
        if isDone {
            return false
        }

        let lastCharOrOverflow = isStarved

        lastChar = char
        if lastCharOrOverflow {
            isFinished = true
            char = "\0"
        } else {
            char = input[end]
            end = input.index(after: end)
            column += 1
        }

        if char == "\n" {
            line += 1
            column = -1
        }

        return !isDone
    }

    func captureToken(_ type: TokenType) -> Token {
        let isStart = start == input.startIndex
        let isEnd = isFinished //end == input.endIndex

        let s = isStart ? start : input.index(before: start)
        let e = isEnd ? end : input.index(before: end)

        if s < end {
            token.string = String(input[start..<e])
        } else {
            token.string = ""
        }
        token.start = input.position(at: start)

        start = e
        token.type = type
        token.line = tokenLine
        token.column = tokenColumn

        tokenLine = line
        tokenColumn = column

        return token
    }

    var isDone: Bool { // True if we are past the last token in the input string
        start >= input.endIndex || isFinished
    }

    var isStarved: Bool { // True if we can no longer add to the current token because we are past the end of the input string
        end >= input.endIndex
    }

    var isFinished = false ///  This is set to true that the moment we have tried to read past the end, that is the first time we are starved

    // Config:

    /// Set the characters that are considered blanks.
    func setValidInBlank(_ validChars: String) {
        blanks.removeAll()
        for ch in validChars {
            blanks.insert(ch)
        }
    }

    /// Returns true if the given char is a blank.
    func isBlank(_ c: Character) -> Bool {
        return blanks.contains(c)
    }

    func addTokenPattern(_ string: String, _ type: TokenType) {
        patterns.addToken(string, index: string.startIndex, type: type)
    }

    private class TokenPattern {
        var type: TokenType = .Text
        var children: [Character: TokenPattern] = [:]

        init(type: TokenType = .Text) {
            self.type = type
        }

        func addToken(_ string: String, index: String.Index, type: TokenType) {
            if index == string.endIndex {
                self.type = type
            } else {
                let ch = string[index]
                var child = children[ch]
                if child != nil {
                    child!.addToken(string, index: string.index(after: index), type: type)
                } else {
                    child = TokenPattern()
                    child!.addToken(string, index: string.index(after: index), type: type)
                    children[ch] = child
                }
            }
        }
    }

    private var patterns = TokenPattern()

    private func createTokenPatterns() {
        addTokenPattern(">", .Quote)
        addTokenPattern("!", .ExclamationMark)
        addTokenPattern("#", .Hash)

        addTokenPattern("**", .Strong)
        addTokenPattern("__", .Strong)
        addTokenPattern("*", .Emphasis)
        addTokenPattern("_", .Emphasis)

        addTokenPattern("[[", .LinkStart)
        addTokenPattern("]]", .LinkEnd)
        addTokenPattern("[", .OpenSBracket)
        addTokenPattern("]", .CloseSBracket)

        addTokenPattern("(", .OpenParent)
        addTokenPattern(")", .CloseParent)

        addTokenPattern("{", .OpenBracket)
        addTokenPattern("}", .CloseBracket)

        addTokenPattern("\n", .NewLine)

        addTokenPattern("- [", .CheckStart)

        setValidInBlank(" \t")
    }
}
