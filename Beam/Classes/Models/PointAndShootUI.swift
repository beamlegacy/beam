import Foundation
import SwiftUI

struct SelectionUI {
    var rect: NSRect
    var animated: Bool
    var color: Color
}

class PointAndShootUI: ObservableObject {

    @Published var pointSelection: SelectionUI?
    @Published var shootSelections: [SelectionUI] = []

    private func drawSelection(selection: NSRect, animated: Bool, color: Color) -> SelectionUI {
        return SelectionUI(rect: selection, animated: animated, color: color)
    }

    func drawPoint(area: NSRect) {
        pointSelection = drawSelection(selection: area, animated: true, color: BeamColor.PointShoot.point.swiftUI)
    }

    func clearPoint() {
        pointSelection = nil
    }

    func drawShoot(shootArea: NSRect, xDelta: CGFloat, yDelta: CGFloat) {
        let newX = shootArea.minX + xDelta
        let newY = shootArea.minY + yDelta
        let shootSelectionUI = SelectionUI(
            rect: NSRect(x: newX, y: newY, width: shootArea.width, height: shootArea.height),
            animated: false,
            color: BeamColor.PointShoot.shoot.swiftUI
        )
        shootSelections.append(shootSelectionUI)
    }

    func clearShoots() {
        shootSelections.removeAll()
    }

    func clear() {
        shootSelections.removeAll()
    }
}
