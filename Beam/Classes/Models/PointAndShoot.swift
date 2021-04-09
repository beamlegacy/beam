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

        func translateTarget(xDelta: CGFloat, yDelta: CGFloat) -> Target {
            let shootArea = self.area
            let newX = shootArea.minX + xDelta
            let newY = shootArea.minY + yDelta
            let newArea = NSRect(x: newX, y: newY, width: shootArea.width, height: shootArea.height)
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
            let scale = page.webPositions.scale
            let xDelta = -page.scrollX * scale
            let yDelta = -page.scrollY * scale
            Logger.shared.logError("drawallshoots: xDelta=\(xDelta), yDelta=\(yDelta)", category: .general)
            for shootTarget in shootTargets {
                let area = shootTarget.area
                let nativeArea = page.webPositions.nativeArea(area: area, origin: origin)
                let target = Target(area: nativeArea, mouseLocation: shootTarget.mouseLocation, html: shootTarget.html)
                ui.drawShoot(shootTarget: target, xDelta: xDelta, yDelta: yDelta)
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
        let scale = page.webPositions.scale
        let xDelta = page.scrollX * scale
        let yDelta = page.scrollY * scale
        for t in targets {
            let textArea = webPositions.nativeArea(area: t.area, origin: origin)
            let scrolledArea = NSRect(x: textArea.minX + xDelta, y: textArea.minY + yDelta, width: textArea.width, height: textArea.height)
            let scrolledMouseLocation = NSPoint(x: t.mouseLocation.x + xDelta, y: t.mouseLocation.y + yDelta)
            let target = Target(area: scrolledArea, mouseLocation: scrolledMouseLocation, html: t.html)
            addShoot(target: target)
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
