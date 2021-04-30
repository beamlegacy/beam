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
    var uis: [SelectionUI]

    let noteInfo: NoteInfo
    var edited: Bool

    init(uis: [SelectionUI], noteInfo: NoteInfo, edited: Bool) {
        ShootGroupUI.latestId += 1
        id = ShootGroupUI.latestId
        self.uis = uis
        self.noteInfo = noteInfo
        self.edited = edited
    }
}

class PointAndShootUI: ObservableObject {

    @Published var pointSelection: SelectionUI?
    @Published var groupsUI: [ShootGroupUI] = []
    @Published var shootConfirmation: SelectionConfirmationUI?
    @Published var isTextSelectionFinished = true
    @Published var swiftPointStatus: String = ""

    private func drawSelection(target: PointAndShoot.Target, animated: Bool,
                               color: Color, bgColor: Color) -> SelectionUI {
        return SelectionUI(target: target, animated: animated, color: color, bgColor: bgColor)
    }

    func drawPoint(target: PointAndShoot.Target) {
        pointSelection = drawSelection(target: target, animated: true, color: BeamColor.PointShoot.point.swiftUI,
                                       bgColor: BeamColor.Generic.transparent.swiftUI)
    }

    func clearPoint() {
        pointSelection = nil
    }

    func createUI(shootTarget: PointAndShoot.Target, xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) -> SelectionUI {
        let shootSelectionUI = SelectionUI(
                target: shootTarget.translateTarget(xDelta: xDelta, yDelta: yDelta, scale: scale),
                animated: false,
                color: BeamColor.PointShoot.shootOutline.swiftUI,
                bgColor: BeamColor.PointShoot.shootBackground.swiftUI
        )
        return shootSelectionUI
    }

    func createGroup(noteInfo: NoteInfo, edited: Bool) -> ShootGroupUI {
        let newGroup = ShootGroupUI(uis: [], noteInfo: noteInfo, edited: edited)
        groupsUI.append(newGroup)
        return newGroup
    }

    func drawShootConfirmation(shootTarget: PointAndShoot.Target, noteInfo: NoteInfo) {
        shootConfirmation = SelectionConfirmationUI(target: shootTarget, noteTitle: noteInfo.title,
                                                    numberOfElements: 1, isText: true)
    }

    func clear() {
        groupsUI.removeAll()
    }

    func clearConfirmation() {
        shootConfirmation = nil
    }
}
