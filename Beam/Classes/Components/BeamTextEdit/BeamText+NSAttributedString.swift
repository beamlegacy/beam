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
                                                            fontColor: node.color,
                                                            caret: caret,
                                                            markedRange: node.markedTextRange,
                                                            selectedRange: selectedRange,
                                                            searchedRanges: node.searchHighlightRanges,
                                                            currentSearchRangeIndex: node.currentSearchHightlight,
                                                            mouseInteraction: mouseInteraction)

        //If current node contains the current search result, block invalidate on hover during the bump animation
        //If not, the layer is redrawn before animation is over.
        if node.currentSearchHightlight != nil {
            node.invalidateOnHover = false
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                node.invalidateOnHover = true
            }
        }

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
        var font: BeamFont
        var strong = strong
        switch elementKind {
        case .heading:
            strong = true
        case .bullet, .code, .quote, .check, .divider, .image, .embed, .blockReference:
            break
        }

        if strong && emphasis{
            font = BeamFont.mediumItalic(size: fontSize)
        } else if strong {
            font = BeamFont.medium(size: fontSize)
        } else if emphasis {
            font = BeamFont.regularItalic(size: fontSize) //NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)
        } else {
            font = BeamFont.regular(size: fontSize)
        }

        return font.nsFont
    }
}
