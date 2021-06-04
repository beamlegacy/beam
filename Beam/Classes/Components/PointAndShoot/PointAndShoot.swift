import Foundation
import BeamCore
import SwiftSoup
import Promises

struct PointAndShootError: LocalizedError {
    var errorDescription: String?
    var failureReason: String?
    var recoverySuggestion: String?
    var helpAnchor: String?

    init(_ desc: String, reason: String? = nil, suggestion: String? = nil, help: String? = nil) {
        errorDescription = desc
        failureReason = reason
        recoverySuggestion = suggestion
        helpAnchor = help
    }
}

public enum PointAndShootStatus: String, CodingKey {
    case none
    case pointing
    case shooting
}

public struct NoteInfo: Encodable {
    let id: UUID?   // Should not be nilable once we get it
    let title: String
}

class PointAndShoot: WebPageHolder {
    var quote: Quote = Quote()
    let parseHtml: ParseHtml = ParseHtml()

    var webPositions: WebPositions = WebPositions()

    var _status: PointAndShootStatus = .none
    var status: PointAndShootStatus {
        get {
            Logger.shared.logDebug("status=\(_status.rawValue)", category: .pointAndShoot)
            return _status
        }
        set {
            if newValue != _status {
                switch newValue {
                case .none:
                    if _status == .pointing {
                        leavePointing()
                        leaveShoot()
                    }

                    if _status == .shooting {
                        leaveShoot()
                    }

                case .shooting:
                    if _status == .pointing {
                        leavePointing()
                    }

                default:
                    Logger.shared.logDebug("setStatus(): from \(_status.rawValue) to \(newValue.rawValue)", category: .pointAndShoot)
                }
                _status = newValue
                if Configuration.pnsStatus {
                    ui.swiftPointStatus = _status.rawValue
                }
            }

            draw()
        }
    }

    var isPointing: Bool {
        @inline(__always) get { status == .pointing }
    }

    private func leavePointing() {
        Logger.shared.logDebug("leavePointing()", category: .pointAndShoot)
        pointTarget = nil
        ui.clearPoint()
    }

    private func leaveShoot() {
        Logger.shared.logDebug("leaveShoot()", category: .pointAndShoot)
        ui.clear()
        activeShootGroup = nil
    }

    func resetStatus() {
        executeJS("setStatus('none')")
    }

    private func executeJS(_ method: String) {
        _ = page.executeJS(method, objectName: "PointAndShoot")
    }

    /**
     * A group of blocks that can be associated to a Note as a whole and at once.
     */
    class ShootGroup {

        let href: String

        init(href: String) {
            self.href = href
        }

        /**
         * The blocks that compose this group.
         */
        var targets: [Target] = []

        var quoteId: UUID?

        /**
         * The associated Note, if any.
         */
        var noteInfo: NoteInfo = NoteInfo(id: nil, title: "")

        func html() -> String {
            targets.reduce("", {
                $1.html.count > $0.count ? $1.html : $0
            })
        }
    }

    struct Target {
        var area: NSRect
        var quoteId: UUID?
        var mouseLocation: NSPoint
        var html: String

        // Prefer using the parent class method
        func translateTarget(xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) -> Target {
            let newArea = NSRect(
                    x: (area.minX + xDelta) * scale,
                    y: (area.minY + yDelta) * scale,
                    width: area.width * scale,
                    height: area.height * scale
            )
            let newLocation = NSPoint(
                    x: mouseLocation.x * scale,
                    y: mouseLocation.y * scale
            )
            return Target(area: newArea, quoteId: quoteId, mouseLocation: newLocation, html: html)
        }
    }

    /// Translates a previously created target based on the page horizontal and vertical scroll and page scaling. Page scaling is calcualted by multiplying the webView zoomLevel and the scaling recieved from JS.
    /// - Parameter target: The target to be translated
    /// - Returns: The translated target
    func translateTarget(target: Target) -> Target {
        guard let view = page.webView else {
            Logger.shared.logError("page webView required to translate target correctly", category: .pointAndShoot)
            return target.translateTarget(xDelta: -page.scrollX, yDelta: -page.scrollY, scale: webPositions.scale)
        }
        let scale = view.zoomLevel() * webPositions.scale
        return target.translateTarget(xDelta: -page.scrollX, yDelta: -page.scrollY, scale: scale)
    }

    /// Creates initial Point and Shoot target that takes into account page horizontal and vertical scroll and page scaling.
    /// Note: When creating a target we position it with scale set to `1`. We call `translateTarget()` before drawing the target which does use the current scaling value.
    /// - Parameters:
    ///   - area: The area coords.
    ///   - quoteId: ID of the stored quote. Defaults to `nil`.
    ///   - mouseLocation: Mouse location coords.
    ///   - html: The HTML content of the targeted element
    /// - Returns: Translated target
    func createTarget(area: NSRect, quoteId: UUID? = nil, mouseLocation: NSPoint, html: String) -> Target {
        return Target(area: area, quoteId: quoteId, mouseLocation: mouseLocation, html: html)
                .translateTarget(xDelta: page.scrollX, yDelta: page.scrollY, scale: 1)
    }

    let ui: PointAndShootUI
    let scorer: BrowsingScorer

    init(ui: PointAndShootUI, scorer: BrowsingScorer) {
        self.ui = ui
        self.scorer = scorer
    }

    /**
     The pointing area (before shoot), if any.

     There is only one at a time.
     */
    var pointTarget: Target?

    /**
     The registered shoot sessions.

     Groups have associated ShootGroupUI managed by the PointAndShootUI
     */
    var shootGroups: [ShootGroup] = []

    /**
      The group being shot.

      It will added to groups once the card has been validated.
     */
    var activeShootGroup: ShootGroup?

    func point(target: Target) {
        executeJS("setStatus('pointing')")
        pointTarget = translateTarget(target: target)
        ui.drawPoint(target: pointTarget!)
        draw()
    }

    func unpoint() {
        if status == .pointing {
            resetStatus()
        }
    }

    func shoot(targets: [Target], href: String) {
        if activeShootGroup == nil {
            activeShootGroup = ShootGroup(href: href)
        }
        activeShootGroup?.targets = targets
    }

    /// update shootGroups with targets
    /// - Parameters:
    ///   - targets: the shoot targets to update
    ///   - href: browser tab href
    func updateShoots(targets: [Target], href: String) {
        let allGroups = [activeShootGroup] + shootGroups
        for group in allGroups.compactMap({ $0 }) {
            let newTargets = targets.filter { target in
                return group.quoteId == target.quoteId
            }

            if newTargets.count > 0 {
                group.targets = newTargets
            }
        }
    }

    func showShootInfo(group: ShootGroup) {
        let shootTarget = translateTarget(target: group.targets[0])
        ui.drawShootConfirmation(shootTarget: shootTarget, noteInfo: group.noteInfo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.ui.clearConfirmation()
        }
    }

    func draw() {
        ui.clear()
        switch status {
        case .pointing:
            drawAllGroups()
        case .shooting:
            drawActiveShootGroup()
        case .none:
            Logger.shared.logDebug("No redraw because pointing=\(status)", category: .pointAndShoot)
        }
    }

    private func drawShootGroup(groups: [ShootGroup], edited: Bool) {
        for group in groups {
            let shootTargets = group.targets
            if shootTargets.count > 0 {
                var selectionUIs = [SelectionUI]()
                for shootTarget in shootTargets {
                    let target = translateTarget(target: shootTarget)
                    let selectionUI = ui.createUI(shootTarget: target)
                    selectionUIs.append(selectionUI)
                }
                _ = ui.createGroup(noteInfo: group.noteInfo, selectionUIs: selectionUIs, edited: edited)
            }
        }
    }

    private func drawAllGroups() {
        drawShootGroup(groups: shootGroups, edited: false)
    }

    private func drawActiveShootGroup() {
        guard let group = activeShootGroup else {
            Logger.shared.logInfo("Skipping drawCurrentGroup() currentGroup not defined", category: .pointAndShoot)
            return
        }
        drawShootGroup(groups: [group], edited: true)
    }

    /**
     Clear all remembered shoots
     */
    func removeAll() {
        shootGroups.removeAll()
        resetStatus()
    }

    /**
     - Parameters:
       - noteTitle:
       - target:
       - additionalText:
     - Throws: PointAndShootError
     */
    func addShootToNote(noteTitle: String, withNote noteText: String? = nil) -> Promise<[ElementKind]> {
        guard let sourceUrl = page.url,
              let currentCard = page.getNote(fromTitle: noteTitle) else {
            return Promise(PointAndShootError("Could not find note to update with title \(noteTitle)"))
        }

        guard let shootGroup = activeShootGroup else {
            fatalError("Expected to have an active shoot group")
        }

        page.setDestinationNote(currentCard, rootElement: currentCard)
        scorer.addTextSelection()

        let htmls = shootGroup.html().split(separator: "\n").compactMap({
            parseHtml.trim(url: sourceUrl, html: String($0))
        })

        var collectedQuotes: [BeamElement] = []
        let promises = htmls.enumerated().map({ (index, html) in
            quote.getQuoteKind(html: html, page: page).then { quoteKind -> Void in
                guard let source = self.page.addToNote(allowSearchResult: true) else {
                    Logger.shared.logError("Could not add note to page", category: .pointAndShoot)
                    return
                }

                var htmlText: BeamText = html2Text(url: sourceUrl, html: html)
                htmlText.addAttributes([.emphasis], to: htmlText.wholeRange)

                let collectedQuote = BeamElement()
                collectedQuote.text = htmlText
                collectedQuote.query = self.page.originalQuery
                collectedQuote.kind = quoteKind

                if let noteText = noteText, !noteText.isEmpty, index == (htmls.endIndex - 1) {
                    let note = BeamElement(BeamText(text: noteText))
                    note.query = self.page.originalQuery
                    collectedQuote.addChild(note)
                }
                source.addChild(collectedQuote)
                collectedQuotes.append(collectedQuote)
            }.catch { error in
                Logger.shared.logError("Could not get quoteKind from html: \(error.localizedDescription)", category: .pointAndShoot)
            }
        })

        return all(promises).then { _ in
            let quoteId = UUID.init()
            let noteInfo = NoteInfo(id: currentCard.id, title: currentCard.title)
            self.complete(noteInfo: noteInfo, quoteId: quoteId, group: shootGroup)
        }
    }

    func complete(noteInfo: NoteInfo, quoteId: UUID, group: ShootGroup) {
        group.quoteId = quoteId
        group.noteInfo = noteInfo
        shootGroups.append(group)
        executeJS("assignNote('\(quoteId)')")
        showShootInfo(group: group)
        activeShootGroup = nil
    }
}
