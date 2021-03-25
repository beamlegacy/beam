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

struct PointAndShootConfig {
    let native: Bool
    let web: Bool
}

class PointAndShoot: ObservableObject {

    let config: PointAndShootConfig

    private var page: WebPage

    init(config: PointAndShootConfig, page: WebPage) {
        self.config = config
        self.page = page
    }

    /**
     * The pointed area.
     *
     * There is only one at a time.
     */
    var pointArea: NSRect?
    @Published var pointSelectionUI: SelectionUI?

    var shootAreas: [NSRect] = []
    @Published var shootSelectionUIs: [SelectionUI] = []

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

    private func drawSelection(selection: NSRect, animated: Bool, color: Color) -> SelectionUI {
        let newX = (Double(pointArea!.minX)) as Double
        let newY = (Double(pointArea!.minY)) as Double
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

    private func drawPoint() {
        pointSelectionUI = pointArea != nil ? drawSelection(selection: pointArea!, animated: true, color: pointColor) : nil
    }

    let shootColor = Color(red: 1, green: 0, blue: 0, opacity: 0.1)

    private func drawShoot(shootArea: NSRect, xDelta: CGFloat, yDelta: CGFloat) -> SelectionUI {
        let newX = shootArea.minX + xDelta
        let newY = shootArea.minY + yDelta
        return SelectionUI(
                rect: NSRect(x: newX, y: newY, width: shootArea.width, height: shootArea.height),
                animated: false,
                color: shootColor
        )
    }

    func drawAllShoots(origin: String) {
        shootSelectionUIs.removeAll()
        if shootAreas.count > 0 {
            let xDelta = -page.scrollX * page.zoomLevel
            let yDelta = -page.scrollY * page.zoomLevel
            for shootArea in shootAreas {
                let nativeArea = page.nativeArea(area: shootArea, origin: origin)
                let shootSelectionUI = drawShoot(shootArea: nativeArea, xDelta: xDelta, yDelta: yDelta)
                shootSelectionUIs.append(shootSelectionUI)
            }
        }
    }

    func point(area: NSRect?) {
        pointArea = area
        if (config.native) {
            drawPoint()
        }
    }

    func addShoot(area: NSRect) {
        shootAreas.append(area)
    }

    func clearAllShoots() {
        shootAreas.removeAll()
        shootSelectionUIs.removeAll()
    }
}