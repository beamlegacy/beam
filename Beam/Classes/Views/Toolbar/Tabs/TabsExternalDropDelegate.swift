//
//  TabsExternalDropDelegate.swift
//  Beam
//
//  Created by Remi Santos on 29/04/2022.
//

import SwiftUI
import UniformTypeIdentifiers

protocol TabsExternalDropDelegateHandler {
    func onDropStarted(location: CGPoint, startLocation: CGPoint, containerGeometry: GeometryProxy)
    func onDropUpdated(location: CGPoint, startLocation: CGPoint, containerGeometry: GeometryProxy)
    func onDropEnded(location: CGPoint, startLocation: CGPoint, cancelled: Bool, containerGeometry: GeometryProxy)
}

/// Replacement for SwiftUI DropDelegate
/// to inject geometry proxy and expose only what's necessary
class TabsExternalDropDelegate: DropDelegate {
    private let handler: TabsExternalDropDelegateHandler
    private let containerGeometry: GeometryProxy
    var startLocation: CGPoint = .zero
    private var dropPerformed = false
    private let supportedTypes = [UTType.beamBrowserTab]

    init(withHandler handler: TabsExternalDropDelegateHandler, containerGeometry: GeometryProxy) {
        self.handler = handler
        self.containerGeometry = containerGeometry
    }

    private func dropInfoIsSupported(_ info: DropInfo) -> Bool {
        info.hasItemsConforming(to: supportedTypes)
    }

    private func triggerHapticFeedback() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .default)
    }

    func dropEntered(info: DropInfo) {
        guard dropInfoIsSupported(info) else { return }
        triggerHapticFeedback()
        dropPerformed = false
        startLocation = info.location
        handler.onDropStarted(location: info.location, startLocation: startLocation, containerGeometry: containerGeometry)
    }

    func dropExited(info: DropInfo) {
        guard dropInfoIsSupported(info) else { return }
        guard !dropPerformed else { return }
        triggerHapticFeedback()
        handler.onDropEnded(location: info.location, startLocation: startLocation, cancelled: true, containerGeometry: containerGeometry)
    }

    func validateDrop(info: DropInfo) -> Bool {
        dropInfoIsSupported(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard dropInfoIsSupported(info) else { return DropProposal(operation: .forbidden) }
        handler.onDropUpdated(location: info.location, startLocation: startLocation, containerGeometry: containerGeometry)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dropInfoIsSupported(info) else { return false }
        dropPerformed = true
        handler.onDropEnded(location: info.location, startLocation: startLocation, cancelled: false, containerGeometry: containerGeometry)
        return true
    }
}
