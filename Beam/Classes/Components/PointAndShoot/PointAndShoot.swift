import Foundation
import BeamCore

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
        /**
         * The blocks that compose this group.
         */
        var targets: [Target] = []

        var quoteId: UUID?

        /**
         * The associated Note, if any.
         */
        var noteInfo: NoteInfo = NoteInfo(id: nil, title: "")

        init() {}

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

    func shoot(targets: [Target], origin: String) {
        if activeShootGroup == nil {
            activeShootGroup = ShootGroup()
            Logger.shared.logInfo("shootGroups.count \(shootGroups.count)", category: .pointAndShoot)
        } else {
            activeShootGroup?.targets.removeAll()
        }
        for target in targets {
            addShootTargets(target: target)
        }
    }

    /**
     Add a shoot to the current group.
     
     - Parameter target: the shoot target to add
     */
    private func addShootTargets(target: Target) {
        guard let group = activeShootGroup else {
            Logger.shared.logWarning("Should have a current group", category: .pointAndShoot)
            return
        }
        group.targets.append(target)
    }

    private func updateShootGroups(target: Target, origin: String) -> Bool {
        guard shootGroups.count > 0 else {
            return false
        }
        for group in shootGroups where group.quoteId == target.quoteId {
            shoot(targets: [target], origin: origin)
            group.targets = activeShootGroup!.targets
            return true
        }
        return false
    }

    /// update shootGroups with targets
    /// - Parameters:
    ///   - targets: the shoot targets to update
    ///   - origin: browser tab origin
    func updateShoots(targets: [Target], origin: String) {
        for target in targets {
            if updateShootGroups(target: target, origin: origin) {
                continue
            }
            shoot(targets: [target], origin: origin)
        }
    }

    func showShootInfo(group: ShootGroup) {
        ui.drawShootConfirmation(shootTarget: group.targets[0], noteInfo: group.noteInfo)
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
                let shootUIGroup = ui.createGroup(noteInfo: group.noteInfo, edited: edited)
                for shootTarget in shootTargets {
                    let target = translateTarget(target: shootTarget)
                    let selectionUI = ui.createUI(shootTarget: target)
                    shootUIGroup.uis.append(selectionUI)
                }
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
     - Throws:
     */
    // swiftlint:disable:next function_body_length
    func addShootToNote(noteTitle: String, withNote additionalText: String? = nil) throws {
        guard let url = page.url,
              let note = page.getNote(fromTitle: noteTitle)
                else {
            Logger.shared.logError("Could not find note with title \(noteTitle)", category: .pointAndShoot)
            return
        }
        page.setDestinationNote(note, rootElement: note)
        let html = activeShootGroup!.html()
        var text = BeamText()
        var embed: String?
        if let host = url.host,
           ["www.youtube.com", "youtube.com"].contains(host),
           html.hasPrefix("<video") {
            embed = url.absoluteString
        }
        text = html2Text(url: url, html: html)
        scorer.addTextSelection()

        // now add a bullet point with the quoted text:
        let title = page.title
        let urlString = url.absoluteString
        var quote = text
        quote.addAttributes([.emphasis], to: quote.wholeRange)

        let quoteE = BeamElement()
        DispatchQueue.main.async {
            guard let current = self.page.addToNote(allowSearchResult: true) else {
                Logger.shared.logError("Ignored current note add", category: .general)
                return
            }
            var quoteParent = current
            if let additionalText = additionalText, !additionalText.isEmpty {
                let quoteElement = BeamElement()
                if let embed = embed {
                    quoteElement.kind = .embed(embed)
                } else {
                    quoteElement.kind = .quote(1, title, urlString)
                }
                quoteElement.text = BeamText(text: additionalText, attributes: [])
                quoteElement.query = self.page.originalQuery
                current.addChild(quoteElement)
                quoteParent = quoteElement
            }

            quoteE.kind = .quote(1, title, urlString)
            quoteE.text = quote
            quoteE.query = self.page.originalQuery
            quoteParent.addChild(quoteE)
        }
        let noteInfo = NoteInfo(id: note.id, title: note.title)
        try complete(noteInfo: noteInfo, quoteId: quoteE.id)
    }

    func complete(noteInfo: NoteInfo, quoteId: UUID) throws {
        guard let group = activeShootGroup else {
            Logger.shared.logWarning("Should have a current group", category: .pointAndShoot)
            return
        }
        group.quoteId = quoteId
        group.noteInfo = noteInfo
        shootGroups.append(group)
        executeJS("assignNote('\(quoteId)')")
        showShootInfo(group: group)
        activeShootGroup = nil
    }
}
