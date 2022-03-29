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
        var fontColor: NSColor

        var caret: Caret?
        var markedRange: Swift.Range<Int>?
        var selectedRange: Swift.Range<Int>?
        var referencesRanges: [Swift.Range<Int>]?
        var searchedRanges: [Swift.Range<Int>]
        var currentSearchRangeIndex: Int?

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
                    attributedString.addAttribute(.underlineColor, value: BeamColor.Editor.underlineAndStrikethrough.staticColor, range: r)
                }
            }

            if let refRanges = config.referencesRanges {
                for refRange in refRanges {
                    if range.range.contains(refRange.lowerBound) && range.range.contains(refRange.upperBound) {
                        let r = NSRange(location: refRange.lowerBound, length: min(range.range.upperBound - refRange.lowerBound, refRange.count))
                        attributedString.addAttribute(.foregroundColor, value: BeamColor.Editor.reference.staticColor, range: r)
                    }
                }
            }

            addImageToLink(attributedString, range, mouseInteraction: config.mouseInteraction)
            string.append(attributedString)
        }

        applySearchRanges(to: string, with: config)

        return string
    }

    private func applySearchRanges(to string: NSMutableAttributedString, with config: Config) {
        let links = config.ranges.filter({ $0.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) })

        for foundRange in config.searchedRanges {

            var isCurrentResult = false
            if let currentResult = config.currentSearchRangeIndex,
               currentResult < config.searchedRanges.count, config.searchedRanges[currentResult] == foundRange {
                isCurrentResult = true
            }

            var linksBefore = 0
            var linksInside = 0
            links.forEach { range in
                if range.end < foundRange.lowerBound {
                    linksBefore += 1
                }
                if foundRange.lowerBound < range.end && range.end < foundRange.lowerBound + foundRange.count {
                    linksInside += 1
                }
            }

            let r = NSRange(location: foundRange.lowerBound + linksBefore, length: foundRange.count + linksInside)

            let color = isCurrentResult ? BeamColor.Search.currentElement.nsColor : BeamColor.Search.foundElement.nsColor
            let attribute: NSAttributedString.Key = isCurrentResult ? .searchCurrentResultBackground : .searchFoundBackground

            if r.location + r.length <= string.length {
                string.addAttribute(attribute, value: color, range: r)
            }
        }
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
        var source: SourceMetadata?
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
        stringAttributes[.foregroundColor] = config.fontColor
        if let link = webLink {
            if let url = URL(string: link) ?? link.toEncodedURL {
                stringAttributes[.link] = url as NSURL
            }
            stringAttributes[.font] = BeamFont.medium(size: config.fontSize).nsFont
            if isCursorCloseToRange {
                stringAttributes[.foregroundColor] = BeamColor.Editor.linkActive.staticColor
                stringAttributes[.boxBackgroundColor] = isCursorInsideRange ?
                    BeamColor.Editor.linkActiveHighlightedBackground.staticColor :
                    BeamColor.Editor.linkActiveBackground.staticColor
            } else {
                stringAttributes[.foregroundColor] = BeamColor.Editor.link.staticColor
                stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                stringAttributes[.underlineColor] = NSColor.clear
                stringAttributes[.hoverUnderlineColor] = BeamColor.Editor.linkDecoration.cgColor
            }
        } else if let link = internalLink {
            stringAttributes[.link] = link
            stringAttributes[.foregroundColor] = BeamColor.Editor.bidirectionalLink.staticColor
            if isCursorCloseToRange {
                stringAttributes[.boxBackgroundColor] = isCursorInsideRange ?
                    BeamColor.Editor.bidirectionalLinkHighlightedBackground.staticColor :
                    BeamColor.Editor.bidirectionalLinkBackground.staticColor
            } else {
                stringAttributes[.hoverUnderlineColor] = BeamColor.Editor.bidirectionalLink.cgColor
                stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                stringAttributes[.underlineColor] = NSColor.clear
            }
        }

        if strikethrough {
            stringAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.strikethroughColor] = BeamColor.Editor.underlineAndStrikethrough.staticColor
        }

        if underline {
            stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.underlineColor] = BeamColor.Editor.underlineAndStrikethrough.staticColor
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

    static var ctRuns: [String: NSAttributedString] = [:]
    static func createGlyphForImage(named imageName: String, color: NSColor?, attributes: [NSAttributedString.Key: Any], offset: CGPoint = .zero) -> NSAttributedString? {
        let id = "\(imageName)-\(color?.componentsRGBAArray ?? [])-\(offset != .zero ? "(\(offset.x),\(offset.y)" : "")"
        if let cachedGlyph = ctRuns[id] {
            let fakeGlyph = NSMutableAttributedString(attributedString: cachedGlyph)
            _ = fakeGlyph.addAttributes(attributes)
            fakeGlyph.removeAttribute(.underlineStyle, range: fakeGlyph.wholeRange)
            fakeGlyph.removeAttribute(.underlineColor, range: fakeGlyph.wholeRange)
            return fakeGlyph
        }
        guard let image = NSImage(named: imageName) else { return nil }
        let extentBuffer = UnsafeMutablePointer<ImageRunStruct>.allocate(capacity: 1)
        extentBuffer.initialize(to: ImageRunStruct(ascent: image.size.height, descent: 0, width: image.size.width, image: imageName, color: color, offset: offset))

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
        let glyph = NSMutableAttributedString(string: " ", attributes: attrDictionaryDelegate)
        ctRuns[id] = glyph

        let fakeGlyph = NSMutableAttributedString(attributedString: glyph)
        _ = fakeGlyph.addAttributes(attributes)
        fakeGlyph.removeAttribute(.underlineStyle, range: fakeGlyph.wholeRange)
        fakeGlyph.removeAttribute(.underlineColor, range: fakeGlyph.wholeRange)
        return fakeGlyph
    }

    func addImageToLink(_ attributedString: NSMutableAttributedString, _ range: BeamText.Range, mouseInteraction: MouseInteraction?) {
        guard attributedString.length > 0 else { return }
        guard range.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) else { return }

        let hasBoxBackground = attributedString.attribute(.boxBackgroundColor, at: 0, effectiveRange: nil) != nil
        let color = hasBoxBackground ? BeamColor.Editor.linkActive.staticColor : BeamColor.Editor.link.staticColor

//        Disabling arrow offset change for now -> BE-2118
//        var offset: CGPoint = .zero
//        if !hasBoxBackground, let mouseInt = mouseInteraction, mouseInt.type == .hovered,
//           ((range.position...range.end).contains(mouseInt.range.upperBound) || BeamText.isPositionOnLinkArrow(mouseInt.range.lowerBound, in: range)) {
//            offset = CGPoint(x: 2, y: 2)
//        }

        let imageName = "editor-url"
        guard let fakeGlyph = Self.createGlyphForImage(named: imageName, color: color, attributes: attributedString.attributes(at: 0, effectiveRange: nil)) else {
            return
        }
        attributedString.append(fakeGlyph)
    }
}
