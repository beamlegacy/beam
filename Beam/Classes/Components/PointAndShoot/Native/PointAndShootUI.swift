import Foundation
import SwiftUI

struct SelectionUI {
    var target: PointAndShoot.Target
    var rect: NSRect {
        target.area
    }
    var animated: Bool
    var color: Color
    var bgColor: Color
    var round: Bool = false
}

struct SelectionConfirmationUI {
    var target: PointAndShoot.Target
    var noteTitle: String
    var numberOfElements: Int
    var isText: Bool
}

public class ShootGroupUI {
    private static var latestId: Int = 0

    let id: Int

    /**
     The selection blocks in this group.

     Can be completed with additional ones.
     */
    let uis: [SelectionUI]

    let noteInfo: NoteInfo
    var edited: Bool

    private(set) var groupPath: CGPath = CGPath(rect: .zero, transform: nil)
    private(set) var groupRect: CGRect = .zero
    private let groupPadding: CGFloat = 4
    private let groupRadius: CGFloat = 4

    init(uis: [SelectionUI], noteInfo: NoteInfo, edited: Bool) {
        ShootGroupUI.latestId += 1
        id = ShootGroupUI.latestId
        self.uis = uis
        self.noteInfo = noteInfo
        self.edited = edited
        self.updateSelectionPath()
    }

    func updateSelectionPath() {
        let fusionRect = ShootFrameFusionRect().getRect(shootSelections: uis).insetBy(dx: -groupPadding, dy: -groupPadding)
        groupRect = fusionRect
        if uis.count > 1 {
            let allRects = uis.map { $0.rect.insetBy(dx: -groupPadding, dy: -groupPadding) }
            groupPath = CGPath.makeUnion(of: allRects, cornerRadius: groupRadius)
        } else {
            groupPath = CGPath(roundedRect: fusionRect, cornerWidth: groupRadius, cornerHeight: groupRadius, transform: nil)
        }
    }
}

class PointAndShootUI: ObservableObject {

    @Published var pointSelection: SelectionUI?
    @Published var groupsUI: [ShootGroupUI] = []
    @Published var shootConfirmation: SelectionConfirmationUI?
    @Published var swiftPointStatus: String = ""
    @Published var pnsBorder: Bool = true

    private func drawSelection(
        target: PointAndShoot.Target,
        animated: Bool,
        color: Color,
        bgColor: Color,
        round: Bool = false
    ) -> SelectionUI {
        return SelectionUI(
            target: target,
            animated: animated,
            color: color,
            bgColor: bgColor,
            round: round
        )
    }

    func drawPoint(target: PointAndShoot.Target) {
        pointSelection = drawSelection(
            target: target,
            animated: true,
            color: BeamColor.PointShoot.text.swiftUI,
            bgColor: BeamColor.PointShoot.pointBackground.swiftUI
        )
    }

    func drawCursor(target: PointAndShoot.Target) {
        pointSelection = drawSelection(
            target: target,
            animated: true,
            color: BeamColor.PointShoot.text.swiftUI,
            bgColor: BeamColor.PointShoot.pointBackground.swiftUI,
            round: true
        )
    }

    func clearPoint() {
        pointSelection = nil
    }

    func createUI(shootTarget: PointAndShoot.Target) -> SelectionUI {
        let shootSelectionUI = SelectionUI(
                target: shootTarget,
                animated: false,
                color: BeamColor.PointShoot.shootOutline.swiftUI,
                bgColor: BeamColor.PointShoot.shootBackground.swiftUI
        )
        return shootSelectionUI
    }

    func createGroup(noteInfo: NoteInfo, selectionUIs: [SelectionUI], edited: Bool) -> ShootGroupUI {
        let newGroup = ShootGroupUI(
            uis: selectionUIs,
            noteInfo: noteInfo,
            edited: edited
        )
        groupsUI.append(newGroup)
        return newGroup
    }

    func drawShootConfirmation(shootTarget: PointAndShoot.Target, noteInfo: NoteInfo) {
        shootConfirmation = SelectionConfirmationUI(
            target: shootTarget,
            noteTitle: noteInfo.title,
            numberOfElements: 1,
            isText: true
        )
    }

    func clearShoots() {
        groupsUI.removeAll()
    }

    func clearConfirmation() {
        shootConfirmation = nil
    }
}
