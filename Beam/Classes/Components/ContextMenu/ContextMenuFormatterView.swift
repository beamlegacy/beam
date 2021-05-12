//
//  ContextMenuFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

// MARK: - NSView Container
class ContextMenuFormatterView: FormatterView {

    private var hostView: NSHostingView<ContextMenuView>?
    private var items: [[ContextMenuItem]] = []
    private var subviewModel = ContextMenuViewModel()
    private var direction: Edge = .bottom
    private var onSelectMenuItem: (() -> Void)?

    override var idealSize: NSSize {
        return ContextMenuView.idealSizeForItems(items)
    }

    convenience init(items: [[ContextMenuItem]], direction: Edge = .bottom, onSelectHandler: (() -> Void)? = nil) {
        self.init(frame: CGRect.zero)
        self.viewType = .inline
        self.items = items
        self.direction = direction
        self.onSelectMenuItem = onSelectHandler
        setupUI()
    }

    override func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        super.animateOnAppear()
        subviewModel.visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.appearAnimationDuration) {
            completionHandler?()
        }
    }

    override func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        super.animateOnDisappear()
        subviewModel.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    override func setupUI() {
        super.setupUI()
        subviewModel.animationDirection = direction
        subviewModel.onSelectMenuItem = onSelectMenuItem
        let rootView = ContextMenuView(viewModel: subviewModel, items: .constant(self.items))
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

}
