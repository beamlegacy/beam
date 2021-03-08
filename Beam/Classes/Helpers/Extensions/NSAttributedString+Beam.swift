//
//  NSAttributedString+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation

extension NSAttributedString {

    static var paragraphSeparator: NSAttributedString {
        return String.paragraphSeparator.attributed
    }

    var wholeRange: NSRange {
        return NSRange(location: 0, length: self.length)
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

class InlineTextAttachment : NSTextAttachment {
    var fontDescender: CGFloat = 0

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> NSRect {
        var superRect = super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
        superRect.origin.y = fontDescender
        return superRect
    }
}
