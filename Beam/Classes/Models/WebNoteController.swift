import Foundation
import BeamCore

class WebNoteController: Encodable, Decodable {

    enum CodingKeys: String, CodingKey {
        case note
        case rootElement
        case element
    }

    public private(set) var note: BeamNote
    public private(set) var rootElement: BeamElement

    public private(set) var element: BeamElement

    var nested: Bool = false

    public var score: Float {
        set {
            element.score = newValue
        }
        get {
            element.score ?? 0
        }
    }

    public var isTodaysNote: Bool {
        note.isTodaysNote
    }

    /**
     Determine which element any add should target.
     */
    private func targetElement(isNavigation: Bool) -> BeamElement {
        guard let latest = element.children.last else {
            element = addElement(isNavigation: isNavigation)
            return element
        }
        element = latest.text.isEmpty ? latest : addElement(isNavigation: isNavigation)
        return element
    }

    private func addElement(isNavigation: Bool) -> BeamElement {
        let newElement = BeamElement()
        if isNavigation && !nested {
            element.addChild(newElement)
            rootElement = element
            nested = true
        } else {
            rootElement.addChild(newElement)
        }
        return newElement
    }

    init(note: BeamNote, rootElement from: BeamElement? = nil) {
        self.note = note
        rootElement = from ?? note
        element = rootElement
    }

    func setDestination(note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
    }

    /*
    Add the current page to the current note. and return
    - Parameter allowSearchResult:
    - Returns: the added (or selected) element
    */
    func add(url: URL, text: String?, isNavigation: Bool = true) -> BeamElement {
        let linkString = url.absoluteString
        let existing: BeamElement? = note.elementContainingLink(to: linkString)
        element = existing ?? targetElement(isNavigation: isNavigation)
        setContents(url: url, text: text)
        Logger.shared.logDebug("add current page '\(text)' with url \(url) to note '\(note.title)'", category: .web)
        return element
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let noteTitle = try container.decode(String.self, forKey: .note)
        let loadedNote = BeamNote.fetch(AppDelegate.main.documentManager, title: noteTitle)
            ?? AppDelegate.main.data.todaysNote
        let rootId = try? container.decode(UUID.self, forKey: .rootElement)
        rootElement = loadedNote.findElement(rootId ?? loadedNote.id) ?? loadedNote.children.first!
        if let elementId = try? container.decode(UUID.self, forKey: .element) {
            guard let foundElement = loadedNote.findElement(elementId) else {
                fatalError("Should have found referenced element \(elementId)")
            }
            element = foundElement
        } else {
            fatalError("Should have found referenced element id")
        }
        note = loadedNote
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        try container.encode(element, forKey: .element)
    }

    private func currentElementIsSimple() -> Bool {
        if element.text.ranges.count == 1 {
            let range = element.text.ranges.first
            return range != nil ? range!.attributes.count <= 1 : true
        }
        return false
    }

    /**
     Set current element text and URL.

     - Parameters:
       - text:
       - url:
     */
    func setContents(url: URL, text: String? = nil) -> String {
        let beamText = element.text
        let titleStr = text ?? beamText.text
        let name = titleStr.isEmpty ? url.absoluteString : titleStr
        if currentElementIsSimple() {
            let attributes = beamText.ranges[0].attributes
            if attributes.isEmpty {    // New contents?
                element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
            } else {
                let attr: BeamText.Attribute = attributes[0]
                if case let .link(url.absoluteString) = attr {
                    element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
                }
            }
        }
        return name
    }
}
