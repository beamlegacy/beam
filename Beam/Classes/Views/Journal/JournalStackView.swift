//
//  JournalStackView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/03/2021.
//

import Foundation
import BeamCore

class JournalStackView: NSView {
    public var horizontalSpace: CGFloat
    public var topOffset: CGFloat
    public var todaysMaxPosition: CGFloat = 0
    public var bottomInset: CGFloat = 0

    private var views: [Int: BeamTextEdit] = [:]
    private var viewCount: Int = 0

    init(horizontalSpace: CGFloat, topOffset: CGFloat) {
        self.horizontalSpace = horizontalSpace
        self.topOffset = topOffset
        super.init(frame: NSRect())
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.backgroundColor = BeamColor.Generic.background.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    public func invalidateLayout() {
        guard !needsLayout else { return }
        invalidateIntrinsicContentSize()
        needsLayout = true
        setNeedsDisplay(bounds)
    }

    public override func layout() {
        relayoutSubViews()
        super.layout()
        needsLayout = false
    }

    private func relayoutSubViews() {
        let textEditViews = self.subviews.compactMap { $0 as? BeamTextEdit }
        var lastViewHeight: CGFloat = .zero
        for (idx, textEdit) in textEditViews.enumerated() {
            textEdit.invalidate()
            if idx != 0 {
                textEdit.frame.origin = CGPoint(x: 0, y: lastViewHeight)
            }
            textEdit.frame.size = NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height)
            if idx == 0 {
                lastViewHeight = topOffset + textEdit.intrinsicContentSize.height + horizontalSpace + bottomInset
            } else {
                lastViewHeight = textEdit.frame.origin.y + textEdit.intrinsicContentSize.height + horizontalSpace
            }
        }
    }

    override public var intrinsicContentSize: NSSize {
        guard let width: CGFloat = getTodaysView()?.intrinsicContentSize.width else { return .zero }
        var height: CGFloat = topOffset * 2.5 + bottomInset
        for view in self.subviews {
          guard let textEditView = view as? BeamTextEdit else { continue }
          height += textEditView.intrinsicContentSize.height + horizontalSpace
        }
        return NSSize(width: width, height: height)
    }

    public func hasChildViews(for note: BeamElement) -> Bool {
       return views.values.contains(where: { $0.note == note })
    }

    public func addChildView(view: BeamTextEdit) {
        if self.subviews.isEmpty {
            view.frame.origin = CGPoint(x: 0, y: topOffset)
            bottomInset = getBottomInsetForTodays(view)
            view.frame.size = NSSize(width: self.frame.width, height: view.intrinsicContentSize.height)
            todaysMaxPosition = topOffset + bottomInset
        } else {
            view.frame.origin = CGPoint(x: 0, y: intrinsicContentSize.height + horizontalSpace - view.cardTopSpace)
            view.frame.size = NSSize(width: self.frame.width, height: view.intrinsicContentSize.height)
        }
        self.addSubview(view)
        views[viewCount] = view
        viewCount += 1
    }

    public func removeChildViews() {
        views.forEach { (_, value) in
            value.removeFromSuperview()
        }
        views.removeAll()
        viewCount = 0
        invalidateLayout()
    }

    private func getBottomInsetForTodays(_ view: BeamTextEdit) -> CGFloat {
        var bottomInset = self.frame.height - (topOffset + view.intrinsicContentSize.height) - view.cardTopSpace - view.cardHeaderLayer.frame.size.height - horizontalSpace
        if bottomInset <= 0 {
            bottomInset = horizontalSpace
        }
        return bottomInset
    }

    public func getTodaysView() -> BeamTextEdit? {
        return views[0]
    }

    public func updateSideLayer(scrollValue: CGFloat, scrollingDown: Bool, y: CGFloat) {
        for view in views {
            let textEditView = view.value
            let minSideLayerTrigger = textEditView.frame.origin.y + textEditView.cardHeaderLayer.frame.origin.y
            let maxSideLayerTrigger = minSideLayerTrigger + textEditView.intrinsicContentSize.height - textEditView.cardTopSpace - textEditView.cardTitleLayer.preferredFrameSize().height

            if y > minSideLayerTrigger && y < maxSideLayerTrigger {
                textEditView.updateSideLayerVisibility(hide: false)

                // Deactivate the update of the side layer position atm
//                textEditView.updateSideLayerPosition(y: scrollValue, scrollingDown: scrollingDown)
            } else {
                textEditView.updateSideLayerVisibility(hide: true)
            }
        }
    }
}
