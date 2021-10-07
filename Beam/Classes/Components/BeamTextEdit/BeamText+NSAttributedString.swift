//
//  BeamText+NSAttributedString.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import AppKit
import BeamCore

extension NSAttributedString.Key {
    static let source = NSAttributedString.Key(rawValue: "beamSource")
    static let hoverUnderlineColor = NSAttributedString.Key(rawValue: "beam_hoverUnderlineColor") // NSColor, default nil
    static let boxBackgroundColor = NSAttributedString.Key(rawValue: "beam_boxBackgroundColor") // NSColor, default nil
    static let searchFoundBackground = NSAttributedString.Key(rawValue: "beam_searchFoundResult") // NSColor, default nil
    static let searchCurrentResultBackground = NSAttributedString.Key(rawValue: "beam_searchCurrentResult") // NSColor, default nil
}

class AttributeDecoratedValueAttributedString: BeamText.AttributeDecoratedValue {
    var attributes: [NSAttributedString.Key: Any]
    init(attributes: [NSAttributedString.Key: Any], editable: Bool) {
        self.attributes = attributes
        super.init()
        self.isEditable = editable
    }
}

extension BeamText {
    init(attributedString: NSAttributedString) {
        self.init()
        append(attributedString.string)

        if let ranges = text.urlRangesInside() {
            ranges.forEach { range in
                let r = range.lowerBound..<range.upperBound
                let linkStr: String = self.extract(range: r).text
                let (isValid, url) = linkStr.validUrl()
                if isValid {
                    self.addAttributes([.link(url)], to: r)
                }
            }
        }
        let boldRanges = attributedString.getRangesOfFont(for: .bold)
        for range in boldRanges {
            let r = range.lowerBound..<range.upperBound
            self.addAttributes([.strong], to: r)
        }
        let emphasisRanges = attributedString.getRangesOfFont(for: .italic)
        for range in emphasisRanges {
            let r = range.lowerBound..<range.upperBound
            self.addAttributes([.emphasis], to: r)
        }

        let linkRanges = attributedString.getLinks()
        for linkRange in linkRanges {
            let range = linkRange.value
            let r = range.lowerBound..<range.upperBound
            let (isValid, url) = linkRange.key.validUrl()
            if isValid {
                self.addAttributes([.link(url)], to: r)
            }
        }
    }

    func buildAttributedString(node: TextNode,
                               caret: Caret?,
                               selectedRange: Swift.Range<Int>?,
                               mouseInteraction: MouseInteraction? = nil) -> NSMutableAttributedString {

        let config = BeamTextAttributedStringBuilder.Config(elementKind: node.elementKind,
                                                            ranges: ranges,
                                                            fontSize: node.fontSize,
                                                            caret: caret,
                                                            markedRange: node.markedTextRange,
                                                            selectedRange: selectedRange,
                                                            searchedRanges: node.searchHighlightRanges,
                                                            currentSearchRangeIndex: node.currentSearchHightlight,
                                                            mouseInteraction: mouseInteraction)
        let builder = BeamTextAttributedStringBuilder()
        return builder.build(config: config)
    }

    static func isPositionOnLinkArrow(_ position: Int, in range: BeamText.Range) -> Bool {
        return position == range.end
    }

    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, elementKind: ElementKind) -> NSFont {
        var font = BeamFont.regular(size: fontSize).nsFont

        switch elementKind {
        case .bullet, .code, .quote, .check, .divider:
            break
        case .heading:
            font = BeamFont.medium(size: fontSize).nsFont
        case .image, .embed, .blockReference:
            break
        }

        if strong {
            font = BeamFont.medium(size: fontSize).nsFont
        }

        if emphasis {
            font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)
        }

        return font
    }
}
