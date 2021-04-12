import Foundation
import SwiftUI

struct SelectionUI {
    var target: PointAndShoot.Target
    var rect: NSRect {
        target.area
    }
    var animated: Bool
    var color: Color
}

struct SelectionConfirmationUI {
    var target: PointAndShoot.Target
    var cardName: String
    var numberOfElements: Int
    var isText: Bool
}

class PointAndShootUI: ObservableObject {

    @Published var pointSelection: SelectionUI?
    @Published var shootSelections: [SelectionUI] = []
    @Published var shootConfirmation: SelectionConfirmationUI?

    private func drawSelection(target: PointAndShoot.Target, animated: Bool, color: Color) -> SelectionUI {
        return SelectionUI(target: target, animated: animated, color: color)
    }

    func drawPoint(target: PointAndShoot.Target) {
        pointSelection = drawSelection(target: target, animated: true, color: BeamColor.PointShoot.point.swiftUI)
    }

    func clearPoint() {
        pointSelection = nil
    }

    func drawShoot(shootTarget: PointAndShoot.Target, xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) {
        let shootSelectionUI = SelectionUI(
            target: shootTarget.translateTarget(xDelta: xDelta, yDelta: yDelta, scale: scale),
            animated: false,
            color: BeamColor.PointShoot.shoot.swiftUI
        )
        shootSelections.append(shootSelectionUI)
    }

    func drawShootConfirmation(shootTarget: PointAndShoot.Target, cardName: String) {
        shootConfirmation = SelectionConfirmationUI(target: shootTarget, cardName: cardName, numberOfElements: 1, isText: true)
    }

    func clearShoots() {
        shootSelections.removeAll()
        shootConfirmation = nil
    }

    func clear() {
        shootSelections.removeAll()
        shootConfirmation = nil
    }
}
