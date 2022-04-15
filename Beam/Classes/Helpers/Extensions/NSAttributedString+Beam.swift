//
//  NSAttributedString+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation
import BeamCore

extension NSAttributedString {

    static var paragraphSeparator: NSAttributedString {
        return String.paragraphSeparator.attributed
    }

    var wholeRange: NSRange {
        return NSRange(location: 0, length: self.length)
    }

    func split(seperateBy: String) -> [NSAttributedString] {
        let input = self.string
        let separatedInput = input.components(separatedBy: seperateBy)
        var output = [NSAttributedString]()
        var start = 0
        for sub in separatedInput {
            let range = NSRange(location: start, length: sub.utf16.count)
            let attribStr = self.attributedSubstring(from: range)
            output.append(attribStr)
            start += range.length + seperateBy.count
        }
        return output
    }

    func getRangesOfFont(for type: NSFontDescriptor.SymbolicTraits) -> [NSRange] {
        var ranges: [NSRange] = []
        self.enumerateAttributes(in: NSRange(location: 0, length: self.length), options: []) { (attributes, range, _) in
            attributes.forEach { (key, value) in
                if key == NSAttributedString.Key.font {
                    guard let font = value as? NSFont else { return }
                    if font.fontDescriptor.symbolicTraits.contains(type) {
                        ranges.append(range)
                    }
                }
            }
        }
        return ranges
    }

    func getLinks() -> [String: NSRange] {
        var ranges: [String: NSRange] = [:]
        self.enumerateAttribute(.link, in: NSRange(0..<self.length)) { value, range, _ in
            if let url = value as? URL {
                ranges[url.absoluteString] = range
            }
        }
        return ranges
    }

    func getRemoteSourceLinks() -> [String: NSRange] {
        var ranges: [String: NSRange] = [:]
        self.enumerateAttribute(.source, in: NSRange(0..<self.length)) { value, range, _ in
            if let metadata = value as? SourceMetadata,
               case .remote(let link) = metadata.origin {
                ranges[link.absoluteString] = range
            }
        }
        return ranges
    }

    func clean(with pattern: String, in range: NSRange) -> NSAttributedString {
        if string.count < range.upperBound { return self }
        guard let cleanAttributedStr = self as? NSMutableAttributedString else { return self }
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let matches = regex?.matches(in: cleanAttributedStr.string, options: [], range: range)
        matches?.reversed().forEach { cleanAttributedStr.replaceCharacters(in: $0.range, with: "") }
        return cleanAttributedStr
    }

    func image(foregroundColor: NSColor? = nil, font: NSFont? = nil) -> NSImage {
        let mutableStr = NSMutableAttributedString(attributedString: self)
        if let foregroundColor = foregroundColor {
            mutableStr.addAttributes([.foregroundColor: foregroundColor],
                                     range: .init(location: 0, length: length))
        }
        if let font = font {
            mutableStr.addAttributes([.font: font],
                                     range: .init(location: 0, length: length))
        }

        let size = mutableStr.size()
        let ceiledSize = NSSize(width: ceil(size.width), height: ceil(size.height))

        let image = NSImage(size: ceiledSize)
        image.lockFocus()
        mutableStr.draw(with: .init(origin: .zero, size: ceiledSize), options: [.usesDeviceMetrics, .usesLineFragmentOrigin])
        image.unlockFocus()
        return image
    }
}

extension NSMutableAttributedString {
    convenience init(withImage image: NSImage, font: NSFont?, spacing: Float?) {
        let attachment = InlineTextAttachment()
        if let font = font {
            attachment.fontDescender = font.descender
        }
        attachment.image = image
        self.init(attachment: attachment)
        if let spacing = spacing {
            append(NSAttributedString(string: "\u{200B}", attributes: [NSAttributedString.Key.kern: spacing]))
        }
    }
}

class InlineTextAttachment: NSTextAttachment {
    var fontDescender: CGFloat = 0

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> NSRect {
        var superRect = super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
        superRect.origin.y = fontDescender
        return superRect
    }
}
