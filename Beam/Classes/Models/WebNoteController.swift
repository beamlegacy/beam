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

    /**
     Point and Shoot content collected from the page
     */
    case pointandshoot
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

    public private(set) var note: BeamNote?
    public var noteOrDefault: BeamNote {
        note ?? Self.defaultNote
    }

    private var _rootElement: BeamElement?
    public private(set) var rootElement: BeamElement {
        get { _rootElement ?? noteOrDefault }
        set { _rootElement = newValue }
    }

    private var _element: BeamElement?
    public private(set) var element: BeamElement {
        get { _element ?? rootElement }
        set { _element = newValue }
    }

    var nested: Bool = false

    public var score: Float {
        get { element.score }
        set { element.score = newValue }
    }

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
        self.note = note
        _rootElement = from
        _element = _rootElement
    }

    func setDestination(note: BeamNote?, rootElement: BeamElement? = nil) {
        self.note = note
        if let rootElement = rootElement ?? note {
            self.rootElement = rootElement
        } else {
            _rootElement = nil
        }
    }

    /// Add the current page to the current note based on the browsing session collection preference.
    /// - Parameters:
    ///   - url: Url of current page
    ///   - text: Text to add
    ///   - reason: Enum reason for adding the note
    ///   - isNavigatingFromNote: Boolean if it's navigating from a note
    ///   - browsingOrigin: browsing tree origin value
    /// - Returns: BeamElement of updated note or nil
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

    /// Add the current page url to the current note. and return
    /// - Parameters:
    ///   - url: Url of current page
    ///   - text: Text to add
    ///   - reason: Enum reason for adding the note
    /// - Returns: BeamElement with added url
    func addContent(url: URL, text: String?, reason: NoteElementAddReason) -> BeamElement {
        let linkString = url.absoluteString
        let noteToUse = noteOrDefault
        let existingLink = noteToUse.elementContainingLink(to: linkString)
        let existingText = (text != nil && !text!.isEmpty ? noteToUse.elementContainingText(someText: text!) : nil)
        element = existingLink ?? existingText ?? targetElement(reason: reason)
        setContents(url: url, text: text)
        Logger.shared.logDebug("add current page '\(text ?? "nil")' with url \(url) to note '\(noteToUse.title)'", category: .web)
        return element
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(UUID.self, forKey: .note),
           let fetchedNote = BeamNote.fetch(AppDelegate.main.documentManager, id: id) {
            note = fetchedNote
            let rootId = try? container.decode(UUID.self, forKey: .rootElement)
            _rootElement = fetchedNote.findElement(rootId ?? fetchedNote.id) ?? fetchedNote.children.first!
            if let elementId = try? container.decode(UUID.self, forKey: .element) {
                guard let foundElement = fetchedNote.findElement(elementId) else {
                    fatalError("Should have found referenced element \(elementId)")
                }
                _element = foundElement
            } else {
                fatalError("Should have found referenced element id")
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let note = note {
            try container.encode(note.id, forKey: .note)
        }
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
