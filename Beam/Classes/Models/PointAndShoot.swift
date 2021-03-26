//
// Created by Jérôme Beau on 19/03/2021.
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
        let newX = (Double(selection.minX)) as Double
        let newY = (Double(selection.minY)) as Double
        return SelectionUI(
                rect: NSRect(
                        x: Float(newX), y: Float(newY),
                        width: Float(selection.width), height: Float(selection.height)
                ),
                animated: animated,
                color: color
        )
    }

    let pointColor = Color(red: 0, green: 0, blue: 0, opacity: 0.1)

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

class PointAndShoot {

    private var page: WebPage

    let ui: PointAndShootUI

    init(page: WebPage) {
        self.page = page
        self.ui = PointAndShootUI()
    }

    /**
     * The pointed area.
     *
     * There is only one at a time.
     */
    var pointArea: NSRect?

    var shootAreas: [NSRect] = []

    lazy var pointAndShoot: String = {
        loadFile(from: "PointAndShoot", fileType: "js")
    }()

    lazy var pointAndShootStyle: String = {
        loadFile(from: "PointAndShoot", fileType: "css")
    }()

    func injectScripts() {
        page.addJS(source: pointAndShoot, when: .atDocumentEnd)
        page.addCSS(source: pointAndShootStyle, when: .atDocumentEnd)
    }

    func drawAllShoots(origin: String) {
        ui.clearShoots()
        if shootAreas.count > 0 {
            let xDelta = -page.scrollX * page.zoomLevel
            let yDelta = -page.scrollY * page.zoomLevel
            for shootArea in shootAreas {
                let nativeArea = page.nativeArea(area: shootArea, origin: origin)
                ui.drawShoot(shootArea: nativeArea, xDelta: xDelta, yDelta: yDelta)
            }
        }
    }

    func point(area: NSRect?) {
        pointArea = area
        if pointArea != nil {
            ui.drawPoint(area: pointArea!)
        } else {
            ui.clearPoint()
        }
    }

    func addShoot(area: NSRect) {
        shootAreas.append(area)
    }

    func clearAllShoots() {
        shootAreas.removeAll()
        ui.clear()
    }
}