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

class PointAndShoot {

    var _status: PointAndShootStatus = .none
    var status: PointAndShootStatus {
        get {
            Logger.shared.logDebug("status=\(_status.rawValue)", category: .pointAndShoot)
            return _status
        }
        set {
            Logger.shared.logDebug("setStatus(\(newValue))", category: .pointAndShoot)
            if newValue != _status {
                switch newValue {
                case .none:
                    if _status == .pointing {   // Allow none from pointing only
                        leavePointing()
                    }
                default:
                    if _status == .shooting {
                        Logger.shared.logDebug("setStatus(): from .shooting to \(newValue)", category: .pointAndShoot)
                        leaveShoot()
                    }
                    _status = newValue
                }
            }
        }
    }

    private func leavePointing() {
        Logger.shared.logDebug("leavePointing()", category: .pointAndShoot)
        clearPoint()
        leaveShoot()    // Pointing mode also displays current shoots
        _status = .none
    }

    private func leaveShoot() {
        Logger.shared.logDebug("leaveShoot()", category: .pointAndShoot)
        ui.clear()
        currentGroup = nil
        executeJS("setStatus('none')")
    }

    private func executeJS(_ method: String) {
        page.executeJS(objectName: "PointAndShoot", jsCode: method)
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

    private var page: WebPage

    let ui: PointAndShootUI

    init(page: WebPage, ui: PointAndShootUI) {
        self.page = page
        self.ui = ui
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

    lazy var pointAndShoot: String = {
        loadFile(from: "index_prod", fileType: "js")
    }()

    lazy var pointAndShootStyle: String = {
        loadFile(from: "index_prod", fileType: "css")
    }()

    func injectScripts() {
        page.addJS(source: pointAndShoot, when: .atDocumentEnd)
        page.addCSS(source: pointAndShootStyle, when: .atDocumentEnd)
    }

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
                                                  scale: page.webPositions.scale)
                    shootUIGroup.uis.append(selectionUI)
                }
            }
        }
    }

    private func drawCurrentGroup() {
        guard let group = currentGroup else { return }
        ui.clear()
        let shootTargets = group.targets
        if shootTargets.count > 0 {
            let xDelta = -page.scrollX
            let yDelta = -page.scrollY
            let shootUIGroup = ui.createGroup(noteInfo: group.noteInfo, edited: true)
            for shootTarget in shootTargets {
                let selectionUI = ui.createUI(shootTarget: shootTarget, xDelta: xDelta, yDelta: yDelta,
                                              scale: page.webPositions.scale)
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
            status = .none
        }
    }

    private func clearPoint() {
        pointTarget = nil
        ui.clearPoint()
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
        status = .none
    }

    func shoot(targets: [Target], origin: String) {
        if currentGroup == nil {
            currentGroup = ShootGroup()
            Logger.shared.logInfo("shoopGroups.count \(groups.count)", category: .pointAndShoot)
        }
        status = .shooting
        let webPositions = page.webPositions
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
        drawCurrentGroup()
    }

    func complete(target: Target, noteInfo: NoteInfo) throws {
        guard let group = currentGroup else {
            Logger.shared.logWarning("Should have a current group", category: .pointAndShoot)
            return
        }
        group.noteInfo = noteInfo
        groups.append(group)
        resetStatus()
        let noteJSON = try JSONEncoder().encode(noteInfo)
        executeJS("assignNote('\(noteInfo)')")
        showShootInfo(group: group)
    }

    func resetStatus() {
        status = .pointing  // Exit from shoot first
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
}
