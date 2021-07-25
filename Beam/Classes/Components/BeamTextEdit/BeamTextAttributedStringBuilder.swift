//
//  BeamTextAttributedStringBuilder.swift
//  Beam
//
//  Created by Remi Santos on 24/06/2021.
//

import Foundation
import BeamCore

struct BeamTextAttributedStringBuilder {
    struct Config {

        var elementKind: ElementKind
        var ranges: [BeamText.Range] = []
        var fontSize: CGFloat

        var caret: Caret?
        var markedRange: Swift.Range<Int>?
        var selectedRange: Swift.Range<Int>?

        var mouseInteraction: MouseInteraction?
    }

    func build(config: Config) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in config.ranges {
            var isSelected = false
            if let selectedRange = config.selectedRange {
                isSelected = !selectedRange.isEmpty && (selectedRange.contains(range.position) || selectedRange.contains(range.end))
            }
            let attributes = attributesForRange(config: config,
                                                range: range,
                                                selected: isSelected)
            var attributedString = NSMutableAttributedString(string: range.string, attributes: attributes)
            if let mouseInteraction = config.mouseInteraction, (range.position...range.end).contains(mouseInteraction.range.upperBound) {
                attributedString = updateAttributes(attributedString, withMouseInteraction: mouseInteraction)
            }

            if let markedRange = config.markedRange {
                if attributedString.string.count >= markedRange.upperBound {
                    let r = NSRange(location: markedRange.lowerBound, length: markedRange.count)
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: r)
                    attributedString.addAttribute(.underlineColor, value: BeamColor.Editor.underlineAndStrikethrough.nsColor, range: r)
                }

            }

            addImageToLink(attributedString, range, mouseInteraction: config.mouseInteraction)
            string.append(attributedString)
        }
        return string
    }

    private func updateAttributes(_ attributedString: NSMutableAttributedString, withMouseInteraction mouseInteraction: MouseInteraction) -> NSMutableAttributedString {
        if mouseInteraction.type == .hovered {
            attributedString.enumerateAttribute(.hoverUnderlineColor, in: attributedString.wholeRange, options: []) { (value, range, _) in
                if let value = value {
                    attributedString.removeAttribute(.underlineColor, range: range)
                    attributedString.addAttribute(.underlineColor, value: value, range: range)
                }
            }
        }
        return attributedString
    }

    private func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        BeamText.font(size, weight: weight)
    }

    private func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, elementKind: ElementKind) -> NSFont {
        BeamText.font(fontSize: fontSize, strong: strong, emphasis: emphasis, elementKind: elementKind)
    }

    private func isCaretCloseToRange(caret: Caret, range: BeamText.Range) -> (isClose: Bool, isInside: Bool) {
        let positionInSource = caret.indexInSource
        let isTrailingChar = caret.edge == .trailing && caret.inSource
        let close = positionInSource >= range.position &&
            (positionInSource < range.end || (positionInSource == range.end && !isTrailingChar))
        var inside = false
        if close {
            inside = positionInSource > range.position &&
                caret.edge != .trailing &&
                (positionInSource < range.end || !caret.inSource)
        }
        return (close, inside)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func attributesForRange(config: Config, range: BeamText.Range, selected: Bool) -> [NSAttributedString.Key: Any] {
        var stringAttributes = [NSAttributedString.Key: Any]()
        var strong = false
        var emphasis = false
        var strikethrough = false
        var underline = false
        var source: String?
        var webLink: String?
        var internalLink: String?
        var decoratedValue: BeamText.AttributeDecoratedValue?
        var isCursorCloseToRange = false
        var isCursorInsideRange = false
        if let caret = config.caret, !selected {
            let closenessInfo = isCaretCloseToRange(caret: caret, range: range)
            isCursorCloseToRange = closenessInfo.isClose
            isCursorInsideRange = closenessInfo.isInside
        }

        for attribute in range.attributes {
            switch attribute {
            case .strong:
                strong = true
            case .emphasis:
                emphasis = true
            case .source(let link):
                source = link
            case .link(let link):
                webLink = link
            case .internalLink(let link):
                internalLink = link.uuidString
            case .strikethrough:
                strikethrough = true
            case .underline:
                underline = true
            case .decorated(let value):
                decoratedValue = value
            }
        }

        stringAttributes[.font] = font(fontSize: config.fontSize, strong: strong, emphasis: emphasis, elementKind: config.elementKind)
        stringAttributes[.foregroundColor] = BeamColor.Generic.text.nsColor
        if let link = webLink {
            if let url = URL(string: link) {
                stringAttributes[.link] = url as NSURL
            } else if let url = URL(string: link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!) {
                stringAttributes[.link] = url as NSURL
            }
            if isCursorCloseToRange {
                stringAttributes[.foregroundColor] = BeamColor.Editor.linkActive.nsColor
                stringAttributes[.boxBackgroundColor] = isCursorInsideRange ?
                    BeamColor.Editor.linkActiveHighlightedBackground.nsColor :
                    BeamColor.Editor.linkActiveBackground.nsColor
            } else {
                stringAttributes[.foregroundColor] = BeamColor.Editor.link.nsColor
                stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                stringAttributes[.underlineColor] = BeamColor.Editor.linkDecoration.nsColor
                stringAttributes[.hoverUnderlineColor] = BeamColor.Editor.link.nsColor
            }
        } else if let link = internalLink {
            stringAttributes[.link] = link
            stringAttributes[.foregroundColor] = BeamColor.Editor.bidirectionalLink.nsColor
            if isCursorCloseToRange {
                stringAttributes[.boxBackgroundColor] = isCursorInsideRange ?
                    BeamColor.Editor.bidirectionalLinkHighlightedBackground.nsColor :
                    BeamColor.Editor.bidirectionalLinkBackground.nsColor
            } else {
                stringAttributes[.hoverUnderlineColor] = BeamColor.Editor.bidirectionalLink.nsColor
                stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                stringAttributes[.underlineColor] = BeamColor.Editor.bidirectionalUnderline.nsColor
            }
        }

        if strikethrough {
            stringAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.strikethroughColor] = BeamColor.Editor.underlineAndStrikethrough.nsColor
        }

        if underline {
            stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.underlineColor] = BeamColor.Editor.underlineAndStrikethrough.nsColor
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        if let decoratedValue = decoratedValue as? AttributeDecoratedValueAttributedString {
            let valueAttributedString = decoratedValue.attributes
            stringAttributes.merge(valueAttributedString, uniquingKeysWith: { $1 })
        }

        return stringAttributes
    }

    func addImageToLink(_ attributedString: NSMutableAttributedString, _ range: BeamText.Range, mouseInteraction: MouseInteraction?) {
        guard attributedString.length > 0 else { return }
        guard range.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) else { return }
        let imageName = "editor-url"
        guard let image = NSImage(named: imageName) else { return }

        let hasBoxBackground = attributedString.attribute(.boxBackgroundColor, at: 0, effectiveRange: nil) != nil
        var color = hasBoxBackground ? BeamColor.Editor.linkActive.nsColor : BeamColor.Editor.linkDecoration.nsColor
        if !hasBoxBackground, let mouseInt = mouseInteraction, mouseInt.type == .hovered, BeamText.isPositionOnLinkArrow(mouseInt.range.lowerBound, in: range) {
            color = BeamColor.Editor.link.nsColor
        }
        let extentBuffer = UnsafeMutablePointer<ImageRunStruct>.allocate(capacity: 1)
        extentBuffer.initialize(to: ImageRunStruct(ascent: image.size.height, descent: 0, width: image.size.width, image: imageName, color: color))

        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { _ in
        }, getAscent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.ascent
        }, getDescent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.descent
        }, getWidth: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.width
        })

        let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)

        let attrDictionaryDelegate = [(kCTRunDelegateAttributeName as NSAttributedString.Key): (delegate as Any)]
        let fakeGlyph = NSMutableAttributedString(string: " ", attributes: attrDictionaryDelegate)
        _ = fakeGlyph.addAttributes(attributedString.attributes(at: 0, effectiveRange: nil))
        fakeGlyph.removeAttribute(.underlineStyle, range: fakeGlyph.wholeRange)
        fakeGlyph.removeAttribute(.underlineColor, range: fakeGlyph.wholeRange)
        attributedString.append(fakeGlyph)
    }
}
