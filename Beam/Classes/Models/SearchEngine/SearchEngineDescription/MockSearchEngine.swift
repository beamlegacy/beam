import Foundation

struct MockSearchEngine: SearchEngineDescription {

    var name: String { "Mock" }
    var description: String { "Mock Search" }

    var searchHost: String { "" }

    func decodeSuggestions(from data: Data) -> [String] { [] }

}
