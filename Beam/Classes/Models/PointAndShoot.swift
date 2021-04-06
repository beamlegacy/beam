//
// Created by Jérôme Beau on 19/03/2021.
//

import Foundation
import BeamCore

class PointAndShoot {

    private var page: WebPage

    let ui: PointAndShootUI

    init(page: WebPage, ui: PointAndShootUI) {
        self.page = page
        self.ui = ui
    }

    /**
     * The pointed area.
     *
     * There is only one at a time.
     */
    var pointArea: NSRect?

    var shootAreas: [NSRect] = []

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

    func drawAllShoots(origin: String) {
        ui.clearShoots()
        if shootAreas.count > 0 {
            let scale = page.webPositions.scale
            let xDelta = -page.scrollX * scale
            let yDelta = -page.scrollY * scale
            Logger.shared.logError("drawallshoots: xDelta=\(xDelta), yDelta=\(yDelta)", category: .general)
            for shootArea in shootAreas {
                let nativeArea = page.webPositions.nativeArea(area: shootArea, origin: origin)
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

    func shootAll(areas: NSArray, origin: String) {
        clearAllShoots()
        let webPositions = page.webPositions
        let scale = page.webPositions.scale
        let xDelta = page.scrollX * scale
        let yDelta = page.scrollY * scale
        for area in areas {
            let jsArea = area as AnyObject
            let rectArea = webPositions.jsToRect(jsArea: jsArea)
            let textArea = webPositions.nativeArea(area: rectArea, origin: origin)
            let scrolledArea = NSRect(x: textArea.minX + xDelta, y: textArea.minY + yDelta, width: textArea.width, height: textArea.height)
            addShoot(area: scrolledArea)
        }
        drawAllShoots(origin: origin)
    }
}
