//
// Created by Jérôme Beau on 26/03/2021.
//

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

    let pointColor = Color(red: 50 / 255, green: 4 / 255, blue: 245 / 255, opacity: 1)

    func drawPoint(area: NSRect) {
        pointSelection = drawSelection(selection: area, animated: true, color: pointColor)
    }

    func clearPoint() {
        pointSelection = nil
    }

    let shootColor = Color(red: 1, green: 0, blue: 0, opacity: 0.1)

    func drawShoot(shootArea: NSRect, xDelta: CGFloat, yDelta: CGFloat) {
        let newX = shootArea.minX + xDelta
        let newY = shootArea.minY + yDelta
        let shootSelectionUI = SelectionUI(
                rect: NSRect(x: newX, y: newY, width: shootArea.width, height: shootArea.height),
                animated: false,
                color: shootColor
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
