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
                Logger.shared.logDebug("setStatus(): from \(_status.rawValue) to \(newValue.rawValue)", category: .pointAndShoot)
                switch newValue {
                case .none:
                    if _status == .pointing {
                        leavePointing()
                        leaveShoot()
                    }

                    if _status == .shooting {
                        leavePointing()
                        leaveShoot()
                    }
                default:
                    if _status == .shooting {
                        Logger.shared.logDebug("setStatus(): from .shooting to \(newValue.rawValue)", category: .pointAndShoot)
                        leaveShoot()
                    }
                }
                _status = newValue
                executeJS("setStatus('\(newValue.rawValue)')")
                if Configuration.pnsStatus {
                    ui.swiftPointStatus = _status.rawValue
                }
            }

            if _status == .shooting {
                drawCurrentGroup()
            }
        }
    }

    private func leavePointing() {
        Logger.shared.logDebug("leavePointing()", category: .pointAndShoot)
        pointTarget = nil
        ui.clearPoint()
    }

    private func leaveShoot() {
        Logger.shared.logDebug("leaveShoot()", category: .pointAndShoot)
        ui.clear()
        currentGroup = nil
    }

    private func executeJS(_ method: String) {
        _ = page.executeJS(method, objectName: "PointAndShoot")
    }

    var isPointing: Bool {
        @inline(__always) get { status == .pointing }
    }

    /**
     * A group of blocks that can be associated to a Note as a whole and at once.
     */
    class ShootGroup {
        /**
         * The blocks that compose this group.
         */
        var targets: [Target] = []

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
        var mouseLocation: NSPoint
        var html: String

        func translateTarget(xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) -> Target {
            let newX = area.minX + xDelta
            let newY = area.minY + yDelta
            let newArea = NSRect(x: newX * scale, y: newY * scale,
                                 width: area.width * scale, height: area.height * scale)
            let newLocation = NSPoint(x: mouseLocation.x + xDelta, y: mouseLocation.y + yDelta)
            return Target(area: newArea, mouseLocation: newLocation, html: html)
        }
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
    var groups: [ShootGroup] = []

    /**
      The group being shot.

      It will added to groups once the card has been validated.
     */
    var currentGroup: ShootGroup?

    func drawAllGroups(someGroup: ShootGroup? = nil) {
        ui.clear()
        for group in groups {
            let shootTargets = group.targets
            if shootTargets.count > 0 {
                let xDelta = -page.scrollX
                let yDelta = -page.scrollY
                let shootUIGroup = ui.createGroup(noteInfo: group.noteInfo, edited: false)
                for shootTarget in shootTargets {
                    let selectionUI = ui.createUI(shootTarget: shootTarget, xDelta: xDelta, yDelta: yDelta,
                                                  scale: webPositions.scale)
                    shootUIGroup.uis.append(selectionUI)
                }
            }
        }
    }

    private func drawCurrentGroup() {
        guard let group = currentGroup else {
            Logger.shared.logInfo("\(String(describing: currentGroup)), Skipping drawCurrentGroup() currentGroup not defined", category: .pointAndShoot)
            return
        }

        if status != .shooting {
            Logger.shared.logInfo("PNS status is \(status.rawValue), Skipping drawCurrentGroup()", category: .pointAndShoot)
            return
        }

        ui.clear()
        let shootTargets = group.targets
        if shootTargets.count > 0 {
            let xDelta = -page.scrollX
            let yDelta = -page.scrollY
            let shootUIGroup = ui.createGroup(noteInfo: group.noteInfo, edited: true)
            for shootTarget in shootTargets {
                let selectionUI = ui.createUI(shootTarget: shootTarget, xDelta: xDelta, yDelta: yDelta,
                                              scale: webPositions.scale)
                shootUIGroup.uis.append(selectionUI)
            }
        }
    }

    func point(target: Target) {
        status = .pointing
        drawAllGroups()         // Show existing shots
        pointTarget = target
        ui.drawPoint(target: target)
    }

    func unpoint() {
        if status == .pointing {
            resetStatus()
        }
    }

    /**
      Add a shoot to the current group.

     - Parameter target: the shoot target to add
     */
    private func addShoot(target: Target) {
        guard let group = currentGroup else {
            Logger.shared.logWarning("Should have a current group", category: .pointAndShoot)
            return
        }
        group.targets.append(target)
    }

    /**
     Clear all remembered shoots
     */
    func removeAll() {
        groups.removeAll()
        resetStatus()
    }

    func shoot(targets: [Target], origin: String, done: Bool = true) {
        if currentGroup == nil {
            currentGroup = ShootGroup()
            Logger.shared.logInfo("shootGroups.count \(groups.count)", category: .pointAndShoot)
        }
        ui.isTextSelectionFinished = done
        let pageScrollX = page.scrollX
        let pageScrollY = page.scrollY
        for target in targets {
            let viewportArea = webPositions.viewportArea(area: target.area, origin: origin)
            let pageArea = NSRect(x: viewportArea.minX + pageScrollX, y: viewportArea.minY + pageScrollY,
                                  width: viewportArea.width, height: viewportArea.height)
            let pageMouseLocation = NSPoint(x: target.mouseLocation.x + pageScrollX,
                                            y: target.mouseLocation.y + pageScrollY)
            let pageTarget = Target(area: pageArea, mouseLocation: pageMouseLocation, html: target.html)
            addShoot(target: pageTarget)
        }

        if status == .pointing {
            status = .shooting
            drawCurrentGroup()
            return
        }
    }

    func complete(noteInfo: NoteInfo) throws {
        guard let group = currentGroup else {
            Logger.shared.logWarning("Should have a current group", category: .pointAndShoot)
            return
        }
        group.noteInfo = noteInfo
        groups.append(group)
        resetStatus()
        let noteJSON = try JSONEncoder().encode(noteInfo)
        executeJS("assignNote('\(noteJSON)')")
        showShootInfo(group: group)
    }

    func resetStatus() {
        status = .none
    }

    func showShootInfo(group: ShootGroup) {
        ui.drawShootConfirmation(shootTarget: group.targets[0], noteInfo: group.noteInfo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.ui.clearConfirmation()
        }
    }

    func draw() {
        switch status {
        case .pointing:
            drawCurrentGroup()
        case .shooting:
            drawAllGroups()
        case .none:
            ui.clear()
        }
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
        let html = currentGroup!.html()
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
            let quoteE = BeamElement()
            quoteE.kind = .quote(1, title, urlString)
            quoteE.text = quote
            quoteE.query = self.page.originalQuery
            quoteParent.addChild(quoteE)
        }
        let noteInfo = NoteInfo(id: note.id, title: note.title)
        try complete(noteInfo: noteInfo)
    }
}
