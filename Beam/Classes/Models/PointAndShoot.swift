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

struct PointMessage {
    var area: NSRect
    var location: NSPoint
    var data: [String: AnyObject]
    var type: [String: AnyObject]
}

class PointAndShoot: ObservableObject {

    init() {

    }

    /**
     * The pointed areas
     */
    @Published var pointSelectionUI: SelectionUI?
    var pointArea: NSRect?

    @Published var shootSelectionUIs: [SelectionUI] = []
    var shootAreas: [NSRect] = []

    lazy var jsSelectionObserver: String = {
        loadFile(from: "SelectionObserver", fileType: "js")
    }()

    lazy var pointAndShoot: String = {
        loadFile(from: "PointAndShoot", fileType: "js")
    }()

    lazy var pointAndShootStyle: String = {
        loadFile(from: "PointAndShoot", fileType: "css")
    }()

    func injectInto(webPage: WebPage) {
        webPage.addJS(source: jsSelectionObserver, when: .atDocumentEnd)
        webPage.addJS(source: pointAndShoot, when: .atDocumentEnd)
        webPage.addCSS(source: pointAndShootStyle, when: .atDocumentEnd)
    }

    let pointColor = Color(red: 0, green: 0, blue: 0, opacity: 0.1)

    private func drawPoint() {
        if self.pointArea != nil {
            let selection = self.pointArea!
            let newX = (Double(self.pointArea!.minX)) as Double
            let newY = (Double(self.pointArea!.minY)) as Double
            self.pointSelectionUI = SelectionUI(
                    rect: NSRect(
                            x: Float(newX), y: Float(newY),
                            width: Float(selection.width), height: Float(selection.height)
                    ),
                    animated: true,
                    color: pointColor
            )
        } else {
            self.pointSelectionUI = nil
        }
    }

    let shootColor = Color(red: 1, green: 0, blue: 0, opacity: 0.1)

    func drawShoot(scrollX: Double, scrollY: Double) {
        if self.shootAreas.count > 0 {
            let xDelta = -scrollX
            let yDelta = -scrollY
            self.shootSelectionUIs = []
            for shootArea in shootAreas {
                let newX = (Double(shootArea.minX) + xDelta) as Double
                let newY = (Double(shootArea.minY) + yDelta) as Double
                let shootSelectionUI: SelectionUI = SelectionUI(
                        rect: NSRect(
                                x: Float(newX), y: Float(newY),
                                width: Float(shootArea.width), height: Float(shootArea.height)
                        ),
                        animated: false,
                        color: shootColor
                )
                self.shootSelectionUIs.append(shootSelectionUI)
            }
        } else {
            self.shootSelectionUIs = []
        }
    }

    func point(area: NSRect?) {
        self.pointArea = area
        drawPoint()
    }

    func shoot(area: NSRect, scrollX: Double, scrollY: Double) {
        self.shootAreas.removeAll()         // TODO: Support multiple shoots
        self.shootAreas.append(area)
        drawShoot(scrollX: scrollX, scrollY: scrollY)
    }
}