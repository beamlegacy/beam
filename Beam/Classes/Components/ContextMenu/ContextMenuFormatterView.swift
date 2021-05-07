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
    private var subviewModel = FormatterViewViewModel()
    private var direction: Edge = .bottom

    override var idealSize: NSSize {
        return ContextMenuView.idealSizeForItems(items)
    }

    convenience init(viewType: FormatterViewType, items: [[ContextMenuItem]], direction: Edge = .bottom) {
        self.init(frame: CGRect.zero)
        self.viewType = viewType
        self.items = items
        self.direction = direction
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
        let rootView = ContextMenuView(viewModel: subviewModel, items: .constant(self.items))
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

}
