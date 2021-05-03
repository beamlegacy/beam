//
//  TextLine.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/03/2021.
//

import Foundation
import BeamCore

public struct ImageRunStruct {
    public let ascent: CGFloat
    public let descent: CGFloat
    public let width: CGFloat
    public let image: String
    public let color: NSColor?
}

public class TextLine {
    public init(ctLine: CTLine, attributedString: NSAttributedString, sourceOffset: Int, notInSourcePositions: [Int]) {
        self.ctLine = ctLine
        self.sourceOffset = sourceOffset
        self.notInSourcePositions = notInSourcePositions
    }

    public var sourceOffset: Int
    public var notInSourcePositions: [Int] = []
    public var localNotInSourcePositions: [Int] {
        notInSourcePositions.compactMap { pos -> Int? in
            let p = pos - range.lowerBound
            return p < 0 || p > range.count ? nil : p
        }
    }

    public var ctLine: CTLine
    public var range: Range<Int> {
        let r = CTLineGetStringRange(ctLine)
        return toSource(r.location) ..< toSource(r.location + r.length)
    }
    public var glyphCount: Int {
        CTLineGetGlyphCount(ctLine)
    }

    public struct Bounds {
        var ascent: Float
        var descent: Float
        var leading: Float
        var width: Float
    }

    public var typographicBounds: Bounds {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let w = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
        return Bounds(ascent: Float(ascent), descent: Float(descent), leading: Float(leading), width: Float(w))
    }

    public var frame = NSRect()

    public var bounds: NSRect { bounds() }
    public func bounds(options: CTLineBoundsOptions = []) -> NSRect {
        return CTLineGetBoundsWithOptions(ctLine, options)
    }

    public var traillingWhiteSpaceWidth: Float {
        Float(CTLineGetTrailingWhitespaceWidth(ctLine))
    }

    public var imageBounds: NSRect {
        return CTLineGetImageBounds(ctLine, nil)
            .offsetBy(dx: frame.origin.x, dy: frame.origin.y)
    }

    public func stringIndexFor(position: CGPoint) -> Int {
        var previous = (carets.first?.offset ?? CGPoint.zero).x
        for caret in carets where caret.edge.isLeading {
            let offset = caret.offset.x
            let middle = CGFloat(0.5 * (offset + previous))
            if middle > position.x {
                return max(0, caret.positionInSource - 1)
            }
            previous = offset
        }
        return carets.last?.positionInSource ?? 0
    }

    public func fromSource(_ index: Int) -> Int {
        let skipped = notInSourcePositions.compactMap { pos -> Int? in
            pos < index ? pos : nil
        }.count
        return index + skipped
    }

    public func toSource(_ index: Int) -> Int {
        let toSkip = notInSourcePositions.compactMap { pos -> Int? in
            pos < index ? pos : nil
        }.count
        return index - toSkip
    }

    public func isAfterEndOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) >= frame.maxX
    }

    public func isBeforeStartOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) <= frame.minX
    }

    public func offsetFor(index: Int) -> CGFloat {
        guard let position = carets.firstIndex(where: { caret -> Bool in caret.positionInSource >= index }) else { return (carets.last?.offset ?? CGPoint(x: frame.minX, y: 0)).x }
        return carets[position].offset.x
    }

    lazy public var carets: [Caret] = {
        var c = [Caret]()
        let y = frame.minY

        CTLineEnumerateCaretOffsets(ctLine) { (offset, index, leading, _) in
            c.append(Caret(offset: CGPoint(x: self.frame.origin.x + CGFloat(offset), y: y), indexInSource: -1, indexOnScreen: index, edge: leading ? .leading : .trailing, inSource: true))
        }

        return sortAndSourceCarets(c, sourceOffset: sourceOffset, notInSourcePositions: notInSourcePositions)
    }()

    public var runs: [CTRun] {
        // swiftlint:disable:next force_cast
        CTLineGetGlyphRuns(ctLine) as! [CTRun]
    }

    public func draw(_ context: CGContext) {
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

    public var interlineFactor: CGFloat = 1.0
}
