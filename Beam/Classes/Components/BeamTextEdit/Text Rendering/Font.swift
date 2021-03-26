//
//  Font.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//
// swiftlint:disable file_length

import Foundation
import AppKit

public class Font {
    class func draw(string: NSAttributedString, atPosition position: NSPoint, textWidth: CGFloat) -> TextFrame {
        assert(textWidth != 0)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake (0, 0),
            nil,
            CGSize(width: CGFloat(textWidth), height: CGFloat.greatestFiniteMagnitude),
            nil)
        //        Logger.shared.logDebug("TextFrame suggested size \(frameSize)")
        let path = CGPath(rect: CGRect(origin: position, size: frameSize), transform: nil)

        let frameAttributes: [String: Any] = [:]
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(),
                                             path,
                                             frameAttributes as CFDictionary)

        let f = TextFrame(ctFrame: frame, position: position, attributedString: string)

        return f
    }
}
