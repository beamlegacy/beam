import Foundation
import BeamCore
import Combine

enum NoteElementAddReason {
    /**
     Page was loaded as the result of a new address typed in the omnibox for instance.
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

    /**
     When the page recieves a title update
     */
    case receivedPageTitle
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

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Inits
    init(note: BeamNote?, rootElement from: BeamElement? = nil) {
        self.note = note
        _rootElement = from
        _element = _rootElement

        setupObservers()
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(UUID.self, forKey: .note),
           let fetchedNote = BeamNote.fetch(id: id, includeDeleted: false) {
            note = fetchedNote
            let rootId = try? container.decode(UUID.self, forKey: .rootElement)
            _rootElement = fetchedNote.findElement(rootId ?? fetchedNote.id) ?? fetchedNote.children.first!
            if let elementId = try? container.decode(UUID.self, forKey: .element),
               let foundElement = fetchedNote.findElement(elementId) {
                _element = foundElement
            } else {
                Logger.shared.logError("Should have found referenced element with id", category: .web)
                _element = nil
            }
        }
        setupObservers()
    }

    private func setupObservers() {
        DocumentManager.documentDeleted.receive(on: DispatchQueue.main).sink { id in
            if self.note?.id == id {
                self.note = nil
            }
            if self._rootElement?.id == id {
                self._rootElement = nil
            }
            if self._element?.id == id {
                self._element = nil
            }
        }.store(in: &cancellables)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let note = note {
            try container.encode(note.id, forKey: .note)
        }
        try container.encode(rootElement.id, forKey: .rootElement)
        try container.encode(element.id, forKey: .element)
    }

    // MARK: - Adding Content to Note
    /// Add provided BeamElements to the Destination Note. If a source is provided, the content will be added
    /// underneath the source url. A new source url will be created if non exists yet.
    /// - Parameters:
    ///   - content: An array of BeamElement to add
    ///   - source: The source url of where content was added from.
    ///   - title: Page title used as title when API request fails
    ///   - reason: Reason for creating a BeamElement
    public func addContent(content: [BeamElement], with source: URL? = nil, title: String? = nil, reason: NoteElementAddReason) async {
        // If a source is provided, and content type should be added with source bullet. Then add content to bullet of the source url
        if let source = source, shouldAddWithSourceBullet(content, pageUrl: source) {
            // If we have an existing one use that, else create a new source bullet
            if let existingSocialTitle = findSocialTitleOnNote(source: source) {
                Logger.shared.logDebug("Source exists, adding \(content) with source:\(source) as child of:\(element)", category: .web)
                element = existingSocialTitle
            } else {
                // Creating SocialTitle
                Logger.shared.logDebug("Source not found, adding \(content) with source:\(source) as child of last element:\(element) of note", category: .web)
                element = getEmptyOrCreateTargetElement(reason: reason)
                let text = await WebNoteController.convertURLToBeamTextLink(url: source, title: title)
                // Update UI back on main thread
                await MainActor.run {
                    element.text = text
                }
            }
        }

        // If the last child of destination element is empty bullet, remove that bullet before adding content
        if let lastChild = element.children.last,
           lastChild.text.isEmpty, lastChild.kind == .bullet {
            // Update UI back on main thread
            await MainActor.run {
                element.removeChild(lastChild)
            }
        }

        // Add content to the note
        Logger.shared.logDebug("Adding content:\(content) as child of:\(element)", category: .web)
        // Update UI back on main thread
        await MainActor.run {
            element.addChildren(content)
        }
    }

    /// Determine which element any add should target.
    /// - Parameter reason: The season for which an element is added
    /// - Returns: returns the target BeamElement
    private func getEmptyOrCreateTargetElement(reason: NoteElementAddReason) -> BeamElement {
        // Get the last child on the targetElement
        // If it's an empty element use the latest.
        if let latest = element.children.last, latest.text.isEmpty {
            return latest
        }

        // When the latest element has content we create a new element to target
        element = createNewTargetElement(reason: reason)
        return element
    }

    /// Creates a new BeamElement, The reason and current position of the rootElement
    /// determines if the new element gets added as a root element or child.
    /// - Parameter reason: The season for which an element is added
    /// - Returns: returns the target BeamElement
    private func createNewTargetElement(reason: NoteElementAddReason) -> BeamElement {
        let newElement = BeamElement()
        if reason == .navigation && !nested {
            // create a new root element
            element.addChild(newElement)
            rootElement = element
            nested = true
        } else {
            // create element as child of root element
            // Update UI back on main thread
            rootElement.addChild(newElement)
        }
        return newElement
    }

    // MARK: - Add Link to Note
    /// Add the current page to the current note based on the browsing session collection preference.
    /// - Parameters:
    ///   - url: Url of current page
    ///   - text: Text to add
    ///   - reason: Enum reason for adding the note
    ///   - isNavigatingFromNote: Boolean if it's navigating from a note
    ///   - browsingOrigin: browsing tree origin value
    /// - Returns: BeamElement of updated note or nil
    public func addLink(url: URL, reason: NoteElementAddReason, isNavigatingFromNote: Bool? = nil, browsingOrigin: BrowsingTreeOrigin? = nil) async -> BeamElement? {
        // With BrowsingSessionCollect enabled AND Navigating from Note
        guard PreferencesManager.browsingSessionCollectionIsOn, isNavigatingFromNote == true else { return nil }

        // collect browsing links
        switch browsingOrigin {
        case .searchFromNode, .browsingNode:
            await addContent(content: [], with: url, reason: reason)
            return element
        default:
            return nil
        }
    }

    public func replaceSearchWithSearchLink(_ search: String, url: URL) async {
        guard noteOrDefault.text.text != search,
              !element.outLinks.contains(url.absoluteString) else {
            return
        }
        let text = await WebNoteController.convertURLToBeamTextLink(url: url)
        // Update UI back on main thread
        await MainActor.run {
            element.text = text
        }
    }

    /// Wrapper around addContent() to simplify adding a source link
    /// - Parameter url: source link to add
    /// - Parameter reason: Enum reason for adding the note
    /// - Returns: The target element that was created or updated
    public func addLink(url: URL, reason: NoteElementAddReason, ignoreExistingSocialTitles: Bool) async {
        await addContent(content: [], with: url, reason: reason)
    }

    // MARK: - Destination Note Methods
    /// Set provided note as target destination for new content.
    /// - Parameters:
    ///   - note: Destination Note
    ///   - rootElement: Element on target note to insert content at. If nill the root of the target note will be used
    public func setDestination(note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        self.element = rootElement ?? note
    }

    /// Removes any target destination note or element and returns it to the default values.
    public func resetDestinationNote() {
        self.note = nil
        self._rootElement = nil
    }

    // This variable could be migrated as a preference if we want. Setting to true gives the original PnS behavior
    var embedMediaInSourceBullet = false
}

// MARK: - Utilities
extension WebNoteController {

    /// Decides if this set of elements should be inserted with a source bullet
    /// - Parameter elements: Array of BeamElement content
    /// - Returns: true if elements should be added under a source bullen
    private func shouldAddWithSourceBullet(_ elements: [BeamElement], pageUrl: URL) -> Bool {
        guard !embedMediaInSourceBullet,
              let first = elements.first,
              elements.count == 1 else { return true }

        // A single Image should be inserted without source bullet
        if first.kind.isMedia {
            return false
        }

        // insert link that could be embed without SocialTitle
        // If the element is a external link of a single embeddable url and
        // the convertLinksToEmbed preference is disabled. The link element should
        // be inserted without source bullet.
        for link in first.outLinks {
            if let url = URL(string: link) {
                let canEmbed = EmbedContentBuilder().canBuildEmbed(for: url)
                let disabledConvertingLinksToEmbed = HtmlVisitor.allowConvertToEmbed == false
                if canEmbed && disabledConvertingLinksToEmbed {
                    return false
                }
            }
        }

        return true
    }

    /// Search destination note for a BeamElement containing the SocialTitle and nothing else.
    /// - Parameter source: The URL to search for
    /// - Returns: BeamElement if element is found. otherwise nil
    private func findSocialTitleOnNote(source: URL) -> BeamElement? {
        if let elementWithLink = noteOrDefault.elementContainingLink(to: source.absoluteString) {
            // Only a valid source link when the link range is the whole text
            for range in elementWithLink.text.linkRanges where range.range == elementWithLink.text.wholeRange {
                return elementWithLink
            }

        }

        return nil
    }

    /// Calls Proxy API to get page title of url
    /// - Parameter url: url for the linkBullet
    /// - Parameter title: Fallback text that will be visible
    /// - Returns: BeamElement with .link
    static func convertURLToBeamTextLink(url: URL, title: String? = nil) async -> BeamText {
        guard url.scheme != "file",
              let link = await SocialTitleFetcher.shared.fetch(for: url),
              let title = link.title.removingPercentEncoding else {
            Logger.shared.logError("API request for link title failed. falling back on page title", category: .web)
            return BeamText(title ?? url.absoluteString, attributes: [.link(url.absoluteString)])
        }

        return BeamText(title, attributes: [.link(link.url.absoluteString)])
    }
}
