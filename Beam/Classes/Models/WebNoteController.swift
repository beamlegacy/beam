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

    public private(set) var element: BeamElement?

    public var score: Float {
        set {
            element?.score = newValue
        }
        get {
            element?.score ?? 0
        }
    }

    public var isTodaysNote: Bool {
        note.isTodaysNote
    }

    init(note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
    }

    /*
     Reset current note's current bullet/block.

      This will result in creating new elements for navigation for instance.
     */
    func clearCurrent() {
        element = nil
    }

    /*
    Add the current page to the current note. and return
    - Parameter allowSearchResult:
    - Returns: the beam element
    */
    func add(text: String, url: URL? = nil) -> BeamElement? {
        guard let url = url else {
            return nil
        }
        let linkString = url.absoluteString
        guard !note.outLinks.contains(linkString) else {
            element = note.elementContainingLink(to: linkString); return element
        }
        Logger.shared.logDebug("add current page '\(title)' to note '\(note.title)'", category: .web)
        if rootElement.children.count == 1,
           let firstElement = rootElement.children.first,
           firstElement.text.isEmpty {
                element = firstElement
           } else {
                let newElement = BeamElement()
                element = newElement
                rootElement.addChild(newElement)
           }
        setCurrent(text: text, url: url)
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
            element = loadedNote.findElement(elementId)
        }
        note = loadedNote
    }

    var title: String {
        note.title
    }

    func setDestination(note: BeamNote, browsingTree: BrowsingTree, rootElement: BeamElement? = nil) -> Bool {
        self.note = note
        self.rootElement = rootElement ?? note
        if let elem = element {
            if elem.children.count == 0 {
                // re-parent the element that has already been created
                // only if it's a single collected link
                self.rootElement.addChild(elem)
            } else {
                clearCurrent()
            }
        }
        addBrowsingTree(browsingTree)
        return element != nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        if let element = element {
            try container.encode(element, forKey: .element)
        }
    }

    func currentElementIsSimple() -> Bool {
        if let element = element,
           element.text.ranges.count == 1 {
            let range = element.text.ranges.first
            return range != nil ? range!.attributes.count <= 1 : true
        }
        return false
    }

    func addBrowsingTree(_ tree: BrowsingTree) {
        note.browsingSessions.append(tree)
    }

    func setCurrent(text: String? = nil, url: URL? = nil) {
        guard let url = url else {
            return
        }
        guard currentElementIsSimple() else {
            return
        }
        let titleStr = text ?? self.title
        let name = titleStr.isEmpty ? url.absoluteString : titleStr
        element?.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
    }
}
