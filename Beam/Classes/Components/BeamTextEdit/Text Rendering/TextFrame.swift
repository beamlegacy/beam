//
//  TextFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/03/2021.
//

import Foundation

public class TextFrame {
    init(ctFrame: CTFrame, position: NSPoint, attributedString: NSAttributedString) {
        self.ctFrame = ctFrame
        self.position = position
        self.attributedString = attributedString

        layout()
    }

    var attributedString: NSAttributedString

    var debug: Bool { lines.count > 1 }
    var ctFrame: CTFrame
    var position: NSPoint
    var lines = [TextLine]()
    var skippablePositions = Set<Int>()

    var visibleRange: Range<Int> {
        let r = CTFrameGetVisibleStringRange(ctFrame)
        return r.location ..< r.location + r.length
    }

    var path: CGPath {
        CTFrameGetPath(ctFrame)
    }

    private var paragraphSpacing: CGFloat {
        if !attributedString.string.isEmpty {
            if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: 0, longestEffectiveRange: nil, in: attributedString.wholeRange) as? NSParagraphStyle {
                return paragraphStyle.paragraphSpacing
            }
        }

        return 0
    }

    private var paragraphSpacingBefore: CGFloat {
        if !attributedString.string.isEmpty {
            if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: 0, longestEffectiveRange: nil, in: attributedString.wholeRange) as? NSParagraphStyle {
                return paragraphStyle.paragraphSpacingBefore
            }
        }

        return 0
    }

    var frame: NSRect {
        var minX = CGFloat(0)
        var maxX = CGFloat(0)
        var minY = CGFloat(0)
        var maxY = CGFloat(0)
        for l in lines {
            let r = l.frame
            minX = min(minX, r.minX)
            maxX = max(maxX, r.maxX)
            minY = min(minY, r.minY)
            maxY = max(maxY, r.maxY)
        }
        if let lastLine = lines.last {
            let lastFrame = lastLine.frame
            maxY = max(maxY, lastFrame.origin.y + lastFrame.height * lastLine.interlineFactor)
        }

        maxY += paragraphSpacing

        return NSRect(x: position.x + minX, y: position.y + minY, width: maxX - minX, height: maxY - minY)
    }

    func layout() {
        if lines.isEmpty {
            skippablePositions = Set<Int>()
            attributedString.enumerateAttribute((kCTRunDelegateAttributeName as NSAttributedString.Key), in: attributedString.wholeRange, options: [], using: { value, range, _ in
                if value != nil {
                    skippablePositions.insert(range.location)
                }
            })

            var sourceOffset = 0
            // swiftlint:disable:next force_cast
            lines = (CTFrameGetLines(ctFrame) as! [CTLine]).map {
                let cfRange = CTLineGetStringRange($0)
                let range = NSRange(location: cfRange.location, length: cfRange.length)
                let line = TextLine(ctLine: $0, attributedString: attributedString, sourceOffset: sourceOffset, skippablePositions: skippablePositions)
                sourceOffset += line.carets.count - 1
                if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: line.range.lowerBound, longestEffectiveRange: nil, in: range) as? NSParagraphStyle {
                    line.interlineFactor = paragraphStyle.lineHeightMultiple
                }
                return line
            }
        }
        if debug {
            //            Logger.shared.logDebug("start layout for \(lines.count) lines")
        }
        var lineOrigins = [CGPoint](repeating: CGPoint(), count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &lineOrigins)

        var Y = CGFloat(0)

        Y += paragraphSpacingBefore

        for i in lines.indices {
            let line = lines[i]
            let textPos = lineOrigins[i]
            let x = textPos.x
            //let y = f.maxY - textPos.y + CGFloat(line.bounds.descent)

            let y = Y // + CGFloat(line.bounds.ascent)

            line.frame = NSRect(x: position.x + x, y: position.y + y, width: line.bounds.width, height: line.bounds.height)

            Y += line.frame.height * line.interlineFactor
            //if debug {
            //Logger.shared.logDebug("     line[\(i)] frame \(line.frame) (textPos \(textPos)")
            //}
        }

        if debug {
            //Logger.shared.logDebug("layout frame \(frame)")
        }
    }

    func draw(_ context: CGContext) {
        if debug {
            //Logger.shared.logDebug("draw frame \(ctFrame)")
        }
        for line in lines {
            line.draw(context)
        }
    }

    lazy var carets: [TextLine.Caret] = {
        filterCarets(allCarets, sourceOffset: 0, skippablePositions: skippablePositions)
    }()

    /// Returns all the carets from the low level CoreText API. There are sorted by offset, not by glyph and the indexOnScreen is counted in bytes in the source string so you will need to process this list before being able to use it for anything useful. The indexInSource is thus -1 for every position.
    lazy var allCarets: [TextLine.Caret] = {
        var carets = [TextLine.Caret]()
        for line in lines {
            carets.append(contentsOf: line.allCarets)
        }
        return carets
    }()

    public func position(before index: Int) -> Int {
        guard !lines.isEmpty, index > 0 else { return 0 }

        var carets = self.carets
        guard var last = allCarets.last else { return index }
        last.indexInSource += 1
        carets.append(last)
        guard let position = carets.firstIndex(where: { caret -> Bool in caret.indexInSource >= index }) else { return index }
        guard position > 0 else { return index }
        return carets[position - 1].indexInSource
    }

    public func position(after index: Int) -> Int {
        guard !lines.isEmpty else { return 0 }

        guard let position = carets.firstIndex(where: { caret -> Bool in caret.indexInSource >= index })
        else { return index }
        guard position + 1 < carets.count else { return index + 1 }
        return carets[position + 1].indexInSource
    }
}
