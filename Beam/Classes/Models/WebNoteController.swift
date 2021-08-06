import Foundation
import BeamCore

enum NoteElementAddReason {
    /**
     Page was loaded as the result of a new address typed in the omnibar for instance.
     */
    case loading

    /**
     Page was loaded following a link in an existing web page.
     */
    case navigation
}

/**
 Rules to log items into notes from web navigation.
 */
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
        get { element.score }
        set { element.score = newValue }
    }

    public var isTodaysNote: Bool {
        note.isTodaysNote
    }
    public var hasSetNote: Bool

    static private var defaultNote: BeamNote {
        AppDelegate.main.data.todaysNote
    }

    /**
     Determine which element any add should target.
     */
    private func targetElement(reason: NoteElementAddReason) -> BeamElement {
        guard let latest = element.children.last else {
            element = addElement(reason: reason)
            return element
        }
        element = latest.text.isEmpty ? latest : addElement(reason: reason)
        return element
    }

    private func addElement(reason: NoteElementAddReason) -> BeamElement {
        let newElement = BeamElement()
        if reason == .navigation && !nested {
            element.addChild(newElement)
            rootElement = element
            nested = true
        } else {
            rootElement.addChild(newElement)
        }
        return newElement
    }

    init(note: BeamNote?, rootElement from: BeamElement? = nil) {
        let notetoUse = note ?? Self.defaultNote
        self.note = notetoUse
        hasSetNote = note != nil
        rootElement = from ?? notetoUse
        element = rootElement
    }

    func setDestination(note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        hasSetNote = true
    }

    /*
    Add the current page to the current note. and return
    - Parameter allowSearchResult:
    - Returns: the added (or selected) element
    */
    public func add(url: URL, text: String?, reason: NoteElementAddReason, isNavigatingFromNote: Bool? = nil, browsingOrigin: BrowsingTreeOrigin? = nil) -> BeamElement? {
        if PreferencesManager.browsingSessionCollectionIsOn {
            return addContent(url: url, text: text, reason: reason)
        } else if !PreferencesManager.browsingSessionCollectionIsOn,
                  let isNavigatingFromNote = isNavigatingFromNote, isNavigatingFromNote {
            switch browsingOrigin {
            case .searchFromNode, .browsingNode:
                return addContent(url: url, text: text, reason: reason)
            default:
                break
            }
        }
        return nil
    }

    private func addContent(url: URL, text: String?, reason: NoteElementAddReason) -> BeamElement {
        let linkString = url.absoluteString
        let existingLink = note.elementContainingLink(to: linkString)
        let existingText = (text != nil && !text!.isEmpty ? note.elementContainingText(someText: text!) : nil)
        element = existingLink ?? existingText ?? targetElement(reason: reason)
        setContents(url: url, text: text)
        Logger.shared.logDebug("add current page '\(text ?? "nil")' with url \(url) to note '\(note.title)'", category: .web)
        return element
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let noteTitle = try container.decode(String.self, forKey: .note)
        let fetchedNote = BeamNote.fetch(AppDelegate.main.documentManager, title: noteTitle)
        let noteToUse = fetchedNote ?? Self.defaultNote
        let rootId = try? container.decode(UUID.self, forKey: .rootElement)
        rootElement = noteToUse.findElement(rootId ?? noteToUse.id) ?? noteToUse.children.first!
        if let elementId = try? container.decode(UUID.self, forKey: .element) {
            guard let foundElement = noteToUse.findElement(elementId) else {
                fatalError("Should have found referenced element \(elementId)")
            }
            element = foundElement
        } else {
            fatalError("Should have found referenced element id")
        }
        note = noteToUse
        hasSetNote = fetchedNote != nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        try container.encode(element.id, forKey: .element)
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
    func setContents(url: URL, text: String? = nil) {
        let beamText = element.text
        let titleStr = text ?? beamText.text
        let name = titleStr.isEmpty ? url.absoluteString : titleStr
        if currentElementIsSimple() {
            var range = beamText.ranges[0]
            let attributes = range.attributes
            if attributes.isEmpty {    // New contents?
                element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
            } else if name == range.string {
                range.attributes = [.link(url.absoluteString)]
            } else {
                let attr: BeamText.Attribute = attributes[0]
                if case .link(url.absoluteString) = attr {
                    element.text = BeamText(text: name, attributes: attributes)
                }
            }
        }
    }
}
