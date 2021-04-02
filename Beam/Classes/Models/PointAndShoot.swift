//
// Created by Jérôme Beau on 19/03/2021.
//

import Foundation

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
        loadFile(from: "PointAndShoot_prod", fileType: "js")
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
