import Foundation

// Copied from Quick/Quick to store JSON DVR Cassettes with better filenames

public extension String {
    private static var invalidCharactersInFilenames: CharacterSet = {
        var invalidCharacters = CharacterSet()

        let invalidCharacterSets: [CharacterSet] = [
            .whitespacesAndNewlines,
            .illegalCharacters,
            .controlCharacters,
            .punctuationCharacters,
            .nonBaseCharacters,
            .symbols
        ]

        for invalidSet in invalidCharacterSets {
            invalidCharacters.formUnion(invalidSet)
        }

        return invalidCharacters
    }()

    var c99ExtendedIdentifier: String {
        let validComponents = components(separatedBy: String.invalidCharactersInFilenames)
        let result = validComponents.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_", options: .literal, range: nil)

        return result.isEmpty ? "_" : result
    }
}
