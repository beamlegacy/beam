//
//  PointAndShootFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/03/2021.
//

import Foundation
import SwiftUI

struct ShootAbsolutePositioning<Content: View>: View {

    var location: CGPoint
    var contentSize: CGSize
    var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let halfWidth = contentSize.width / 2
            let maxX = geo.size.width - halfWidth - 5
            let x = (location.x + halfWidth).clamp(halfWidth, maxX)
            content()
                .position(x: x, y: location.y + contentSize.height / 2 + 5)
        }
    }
}

struct ShootFrame: View {
    @EnvironmentObject var state: BeamState

    @ObservedObject var pointAndShootUI: PointAndShootUI

    var fusionRect: CGRect {
        var minX: CGFloat = 5000
        var minY: CGFloat = 5000
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        pointAndShootUI.shootSelections.forEach { (selection) in
            let rect = selection.rect
            if rect.minX < minX {
                minX = rect.minX
            }
            if rect.minY < minY {
                minY = rect.minY
            }
            if rect.maxX > maxX {
                maxX = rect.maxX
            }
            if rect.maxY > maxY {
                maxY = rect.maxY
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    var body: some View {
        ZStack {
            let padding: CGFloat = 6
            if let selectionUI = pointAndShootUI.shootSelections.first {
                let rect = pointAndShootUI.shootSelections.count == 1 ? selectionUI.rect : fusionRect
                RoundedRectangle(cornerRadius: padding, style: .continuous)
                        .stroke(BeamColor.Beam.swiftUI, lineWidth: 2)
                        .padding(-padding)
                        .animation(selectionUI.animated ? Animation.easeOut : nil)
                        .offset(x: rect.minX, y: rect.minY)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.width / 2, y: rect.height / 2)
            }
            if let selectionUI = pointAndShootUI.shootSelections.last {
                ShootAbsolutePositioning(location: selectionUI.target.mouseLocation, contentSize: ShootCardPicker.size) {
                    ShootCardPicker()
                        .onComplete { (cardName, note) in
                            onSelectCard(cardName, withNote: note)
                        }
                }
            }
            if let confirmationUI = pointAndShootUI.shootConfirmation {
                ShootAbsolutePositioning(location: confirmationUI.target.mouseLocation, contentSize: ShootCardConfirmationView.size) {
                    ShootCardConfirmationView(cardName: confirmationUI.cardName, numberOfElements: confirmationUI.numberOfElements, isText: confirmationUI.isText)
                }
            }
        }
        .animation(nil)
    }

    func onSelectCard(_ cardName: String?, withNote note: String?) {
        if let cardName = cardName, let selection = pointAndShootUI.shootSelections.last {
            pointAndShootUI.clearShoots()
            state.currentTab?.addSelectionToCard(cardName: cardName, target: selection.target, withNote: note)
        }
    }

}
