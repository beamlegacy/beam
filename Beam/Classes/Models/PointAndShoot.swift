//
// Created by Jérôme Beau on 19/03/2021.
//

import Foundation
import BeamCore

class PointAndShoot {

    struct Target {
        var area: NSRect
        var mouseLocation: NSPoint
        var html: String

        func translateTarget(xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) -> Target {
            let shootArea = self.area
            let newX = shootArea.minX + xDelta
            let newY = shootArea.minY + yDelta
            let newArea = NSRect(x: newX * scale, y: newY * scale,
                                 width: shootArea.width * scale, height: shootArea.height * scale)
            let newLocation = NSPoint(x: self.mouseLocation.x + xDelta, y: self.mouseLocation.y + yDelta)
            return Target(area: newArea, mouseLocation: newLocation, html: self.html)
        }
    }

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
    var pointTarget: Target?

    var shootTargets: [Target] = []

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
        if shootTargets.count > 0 {
            let xDelta = -page.scrollX
            let yDelta = -page.scrollY
            for shootTarget in shootTargets {
                ui.drawShoot(shootTarget: shootTarget, xDelta: xDelta, yDelta: yDelta, scale: page.webPositions.scale)
            }
        }
    }

    func point(target: Target?) {
        pointTarget = target
        if let t = target {
            ui.drawPoint(target: t)
        } else {
            ui.clearPoint()
        }
    }

    private func addShoot(target: Target) {
        shootTargets.append(target)
    }

    func clearAllShoots() {
        shootTargets.removeAll()
        ui.clear()
    }

    func shootAll(targets: [Target], origin: String) {
        clearAllShoots()
        let webPositions = page.webPositions
        let pageScrollX = page.scrollX
        let pageScrollY = page.scrollY
        for t in targets {
            let viewportArea = webPositions.viewportArea(area: t.area, origin: origin)
            let pageArea = NSRect(x: viewportArea.minX + pageScrollX, y: viewportArea.minY + pageScrollY, width: viewportArea.width, height: viewportArea.height)
            let pageMouseLocation = NSPoint(x: t.mouseLocation.x + pageScrollX, y: t.mouseLocation.y + pageScrollY)
            let pageTarget = Target(area: pageArea, mouseLocation: pageMouseLocation, html: t.html)
            addShoot(target: pageTarget)
        }
        drawAllShoots(origin: origin)
    }

    func shootConfirmation(target: Target, cardName: String, origin: String) {
        clearAllShoots()
        ui.drawShootConfirmation(shootTarget: target, cardName: cardName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.clearAllShoots()
        }
    }
}
