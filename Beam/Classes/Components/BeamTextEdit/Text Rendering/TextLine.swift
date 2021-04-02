//
//  TextLine.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/03/2021.
//

import Foundation

struct ImageRunStruct {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat
    let image: String
    let color: NSColor?
}

func filterCarets(_ carets: [TextLine.Caret], sourceOffset: Int, skippablePositions: [Int]) -> [TextLine.Caret] {
    var count = sourceOffset
    let filtered = carets.sorted { (lhs, rhs) -> Bool in
        if lhs.indexOnScreen < rhs.indexOnScreen { return true }
        if (lhs.indexOnScreen == rhs.indexOnScreen) && (lhs.offset < rhs.offset) { return true }

        return false
    }.compactMap { caret -> TextLine.Caret? in
        if caret.isLeadingEdge && !skippablePositions.contains(caret.indexOnScreen) {
            var c = caret
            c.indexInSource = count
            count += 1
            return c
        }
        return nil
    }

    guard var last = carets.last else { return filtered }
    last.indexInSource = count
    return filtered + [last]
}

public class TextLine {
    init(ctLine: CTLine, attributedString: NSAttributedString, sourceOffset: Int, skippablePositions: [Int]) {
        self.ctLine = ctLine
        self.sourceOffset = sourceOffset
        self.skippablePositions = skippablePositions
    }

    var sourceOffset: Int
    var skippablePositions: [Int] = []
    var localSkippablePositions: [Int] {
        skippablePositions.compactMap { pos -> Int? in
            let p = pos - range.lowerBound
            return p < 0 || p > range.count ? nil : p
        }
    }

    var ctLine: CTLine
    var range: Range<Int> {
        let r = CTLineGetStringRange(ctLine)
        return toSource(r.location) ..< toSource(r.location + r.length)
    }
    var glyphCount: Int {
        CTLineGetGlyphCount(ctLine)
    }

    struct Bounds {
        var ascent: Float
        var descent: Float
        var leading: Float
        var width: Float
    }

    var typographicBounds: Bounds {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let w = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
        return Bounds(ascent: Float(ascent), descent: Float(descent), leading: Float(leading), width: Float(w))
    }

    var frame = NSRect()

    var bounds: NSRect { bounds() }
    func bounds(options: CTLineBoundsOptions = []) -> NSRect {
        return CTLineGetBoundsWithOptions(ctLine, options)
    }

    var traillingWhiteSpaceWidth: Float {
        Float(CTLineGetTrailingWhitespaceWidth(ctLine))
    }

    var imageBounds: NSRect {
        return CTLineGetImageBounds(ctLine, nil)
            .offsetBy(dx: frame.origin.x, dy: frame.origin.y)
    }

    func stringIndexFor(position: NSPoint) -> Int {
        var previous = Float(0)
        let range = CTLineGetStringRange(ctLine)
        for caret in carets {
            let offset = caret.offset
            let middle = CGFloat(0.5 * (offset + previous))
            if middle > position.x {
                return caret.indexInSource
            }
            previous = offset
        }
        return toSource(range.location + range.length)
    }

    func fromSource(_ index: Int) -> Int {
        let skipped = skippablePositions.compactMap { pos -> Int? in
            pos < index ? pos : nil
        }.count
        return index + skipped
    }

    func toSource(_ index: Int) -> Int {
        let toSkip = skippablePositions.compactMap { pos -> Int? in
            pos < index ? pos : nil
        }.count
        return index - toSkip
    }

    func isAfterEndOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) >= frame.maxX
    }

    func isBeforeStartOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) <= frame.minX
    }

    func offsetFor(index: Int) -> Float {
        guard let position = carets.firstIndex(where: { caret -> Bool in caret.indexInSource >= index }) else { return allCarets.last?.offset ?? Float(frame.minX) }
        return carets[position].offset
    }

    struct Caret {
        var offset: Float
        var indexInSource: Int
        var indexOnScreen: Int
        var isLeadingEdge: Bool
    }

    var carets: [Caret] {
        filterCarets(allCarets, sourceOffset: sourceOffset, skippablePositions: skippablePositions)
    }

    /// Returns all the carets from the low level CoreText API. There are sorted by offset, not by glyph and the indexOnScreen is counted in bytes in the source string so you will need to process this list before being able to use it for anything useful. The indexInSource is thus -1 for every position.
    var allCarets: [Caret] {
        var c = [Caret]()
        CTLineEnumerateCaretOffsets(ctLine) { (offset, index, leading, _) in
            c.append(Caret(offset: Float(self.frame.origin.x) + Float(offset), indexInSource: -1, indexOnScreen: index, isLeadingEdge: leading))
        }

        return c
    }

    var runs: [CTRun] {
        // swiftlint:disable:next force_cast
        CTLineGetGlyphRuns(ctLine) as! [CTRun]
    }

    func draw(_ context: CGContext) {
        context.saveGState()
        context.textPosition = NSPoint()//line.frame.origin
        context.translateBy(x: frame.origin.x, y: frame.origin.y)
        context.scaleBy(x: 1, y: -1)

        CTLineDraw(ctLine, context)

        // draw strikethrough or link icon if needed:
        var offset = CGFloat(0)
        for run in runs {
            var ascent = CGFloat(0)
            var descent = CGFloat(0)

            let width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil)

            if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] {

                if let color = attributes[.strikethroughColor] as? NSColor,
                   attributes[.strikethroughStyle] as? NSNumber != nil {
                    context.setStrokeColor(color.cgColor)

                    let  y = CGFloat(roundf(Float(ascent / 3.0)))

                    context.move(to: CGPoint(x: offset, y: y))
                    context.addLine(to: CGPoint(x: offset + CGFloat(width), y: y))
                    context.strokePath()
                }
                if let delegateAttribute = attributes[kCTRunDelegateAttributeName as NSAttributedString.Key] {
                    // swiftlint:disable:next force_cast
                    let delegate: CTRunDelegate = delegateAttribute as! CTRunDelegate
                    let imageRunRef = CTRunDelegateGetRefCon(delegate)
                    let imageRunPtr = imageRunRef.assumingMemoryBound(to: ImageRunStruct.self)
                    let imageRun = imageRunPtr.pointee
                    let imageName = imageRun.image
                    guard let image = NSImage(named: imageName) else { continue }

                    var rect = CGRect(origin: CGPoint(x: offset + 1, y: 4), size: image.size)
                    guard let cgImage = image.cgImage(forProposedRect: &rect,
                                                      context: nil,
                                                      hints: nil) else { continue }
                    context.setBlendMode(.normal)
                    context.draw(cgImage, in: rect)
                    if let imageColor = imageRun.color {
                        context.setBlendMode(.sourceIn)
                        context.setFillColor(imageColor.cgColor)
                        context.fill(rect)
                    }
                }
            }

            offset += CGFloat(width)
        }

        // Done!
        context.restoreGState()
    }

    var interlineFactor: CGFloat = 1.0
}
