//
//  TouchBarController.swift
//  Beam
//
//  Created by Remi Santos on 28/06/2022.
//

import Foundation
import BeamCore
import Combine
import AppKit
import SwiftUI

class TouchBarController: NSObject {

    private weak var window: BeamWindow?
    private var cancellables = Set<AnyCancellable>()

    init(window: BeamWindow) {
        self.window = window
        super.init()

        window.state.$canGoBackForward.sink { [weak self] _ in
            self?.updateTouchBar()
        }.store(in: &cancellables)
    }

    func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = .mainBar
        var items: [NSTouchBarItem.Identifier] = [.navigationItem]
        if showLaserPistol || (window?.state.mode == .web && window?.state.browserTabsManager.currentTab?.url?.host == "beamapp.co") {
            items.append(.laserItem)
        } else if window?.state.mode != .web {
            items.append(.hiddenLaserItem)
        }
        items.append(.otherItemsProxy)
        touchBar.defaultItemIdentifiers = items
        return touchBar
    }

    func updateForBrowserTabChange() {
        updateTouchBar()
    }

    private func updateTouchBar() {
        window?.touchBar = nil // best way to relayout the touchbar
    }

    @objc private func goBack() {
        window?.navigateBack(self)
    }

    @objc private func goForward() {
        window?.navigateForward(self)
    }

    private var showLaserPistol = false {
        didSet {
            updateTouchBar()
        }
    }
    private var tapCount = 0
    private var lastTap = BeamDate.now
    private var lastShotDispatchItem: DispatchWorkItem?
    private let numberOfTapsToShowPistol = 3
    @objc private func hiddenLaserTapped() {
        guard !showLaserPistol else { return }
        let interval = -lastTap.timeIntervalSinceNow
        if interval < 0.5 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTap = .init()
        guard tapCount >= numberOfTapsToShowPistol else { return }
        showLaserPistol = true
        let workItem = DispatchWorkItem { [weak self] in
            self?.resetLaserPistol()
        }
        lastShotDispatchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: workItem)
    }

    private func laserTapped() {
        lastShotDispatchItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.resetLaserPistol()
        }
        lastShotDispatchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: workItem)
    }

    private func resetLaserPistol() {
        lastShotDispatchItem = nil
        tapCount = 0
        showLaserPistol = false
    }
}

extension TouchBarController: NSTouchBarDelegate {

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .navigationItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let leftButton = NSButton(
                image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "navigate back")!,
                target: self, action: #selector(goBack))
            leftButton.isEnabled = window?.state.canGoBackForward.back == true
            let rightButton = NSButton(
                image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "navigate forward")!,
                target: self, action: #selector(goForward))
            rightButton.isEnabled = window?.state.canGoBackForward.forward == true
            let stackView = NSStackView(views: [leftButton, rightButton])
            stackView.spacing = 1
            item.view = stackView
            return item
        case .hiddenLaserItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "🔫", target: self, action: #selector(hiddenLaserTapped))
            button.alphaValue = 0
            item.view = button
            return item
        case .laserItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let rootView = LightBeamViewTouchBarContainer { [weak self] in
                self?.laserTapped()
            }
            let view = NSView()
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.autoresizingMask = [.width, .height]
            view.addSubview(hostingView)
            view.wantsLayer = true
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            item.view = view
            return item
        default:
            return nil
        }
    }
}

extension NSTouchBarItem.Identifier {
    static let navigationItem = NSTouchBarItem.Identifier("co.beamapp.touchbar.navigationItem")
    static let hiddenLaserItem = NSTouchBarItem.Identifier("co.beamapp.touchbar.hiddenLaserItem")
    static let laserItem = NSTouchBarItem.Identifier("co.beamapp.touchbar.laserItem")
}

extension NSTouchBar.CustomizationIdentifier {
    static let mainBar = NSTouchBar.CustomizationIdentifier("co.beamapp.touchbar.mainBar")
}
