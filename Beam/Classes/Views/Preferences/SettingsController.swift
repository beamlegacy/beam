//
//  SettingsController.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import Foundation
import BeamCore

final class SettingsController: NSViewController {
    var settingsTab = [SettingTab]()
    var selectedTab: SettingTab?

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    func configure(settingsTab: [SettingTab]) {
        self.settingsTab = settingsTab
        guard let firstTab = settingsTab.first else { return }
        view = firstTab.view
        selectedTab = firstTab
    }

    func tab(for identifier: String) -> SettingTab? {
        return settingsTab.first(where: { $0.label == identifier })
    }

    func selectItem(_ item: String) {
        let selectedItem = settingsTab.first { $0.label == item }
        guard let selectedView = selectedItem?.view, selectedItem != selectedTab else { return }
        animate(to: selectedView, with: selectedItem?.label ?? "")
        selectedTab = selectedItem
    }

    func animate(to view: NSView, with title: String) {
        guard let window = self.view.window else { return }
        var frame = window.frame
        let oldFrame = frame
        let oldSize = window.contentRect(forFrameRect: frame).size

        let dX = view.intrinsicContentSize.width - oldSize.width
        let dY = view.intrinsicContentSize.height - oldSize.height

        frame.origin.y -= dY
        frame.size.width += dX
        frame.size.height += dY

        DispatchQueue.main.asyncAfter(deadline: .now()+window.animationResizeTime(frame)) {
            self.view = view
            window.title = loc(title, comment: "Preferences Window Title")
            window.setFrame(frame, display: true, animate: false)
        }
        self.view = NSView(frame: oldFrame)
        window.setFrame(frame, display: true, animate: true)
    }
}
