//
//  OldJournalStackView.swift
//  Beam
//
//  Created by Sebastien Metrot on 14/12/2021.
//

import Foundation
import BeamCore

class JournalStackView: JournalSimpleStackView {
    //swiftlint:disable:next function_body_length
    override func layout() {
        guard let scrollView = enclosingScrollView else { return }
        defer {
            countChanged = false
            initialLayout = false
        }

        var secondNoteY = CGFloat(0)
        let clipView = scrollView.contentView

        let textEditViews = self.notes.compactMap { views[$0] }
        var lastViewY = topOffset
        var first = true

        let animateMoves = countChanged && !initialLayout
        if animateMoves {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.2
        }

        defer {
            if animateMoves {
                NSAnimationContext.endGrouping()
            }
        }

        let scrollPosition = clipView.bounds.origin.y
        let clipHeight = clipView.bounds.height

        for textEdit in textEditViews {
            if first {
                let firstNoteHeight = topOffset + textEdit.intrinsicContentSize.height + verticalSpace
                secondNoteY = max(clipHeight, firstNoteHeight) - safeTop

                if scrollPosition <= secondNoteY - (topOffset + textEdit.intrinsicContentSize.height + safeTop) {
                    if textEdit.superview == self {
                        enclosingScrollView?.addFloatingSubview(textEdit, for: .vertical)
                    }

                    let elastic = min(0, safeTop + scrollPosition)
                    let posY = topOffset - elastic
                    let newFrame = NSRect(origin: CGPoint(x: 0, y: posY),
                                          size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))
                    textEdit.frame = newFrame
                    lastViewY = secondNoteY
                    first = false
                    continue
                }
                lastViewY = secondNoteY - textEdit.intrinsicContentSize.height - verticalSpace
                if textEdit.superview != self {
                    addSubview(textEdit)
                }
            }
            let newFrame = NSRect(origin: CGPoint(x: 0, y: lastViewY),
                                  size: NSSize(width: self.frame.width, height: textEdit.intrinsicContentSize.height))
            if !textEdit.frame.isEmpty && !first && animateMoves {
                textEdit.animator().frame = newFrame
            } else {
                textEdit.frame = newFrame
            }

            lastViewY = (first ? secondNoteY : newFrame.maxY + verticalSpace).rounded()
            first = false
        }
    }

    override public var intrinsicContentSize: NSSize {
        guard let firstNote = notes.first,
              let textEdit = views[firstNote],
              let scrollView = enclosingScrollView
        else { return .zero }

        let width = textEdit.intrinsicContentSize.width
        let clipView = scrollView.contentView
        let clipHeight = clipView.bounds.height
        let firstNoteHeight = topOffset + textEdit.intrinsicContentSize.height + verticalSpace
        let secondNoteY = max(clipHeight, firstNoteHeight) - safeTop

        var height = secondNoteY
        var first = true
        for note in self.notes {
            if !first, let textEdit = views[note] {
              height += textEdit.intrinsicContentSize.height + verticalSpace
            }
            first = false
        }

        height += topOffset
        return NSSize(width: width, height: height)
    }

    override func updateScrollingFrames() {
        layout()
    }
}
