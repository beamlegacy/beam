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
    public var offset: CGPoint = .zero
}

public class TextLine {

    public init(indexInFrame: Int, ctLine: CTLine, attributedString: NSAttributedString, sourceOffset: Int, caretOffset: Int, notInSourcePositions: [Int]) {
        self.indexInFrame = indexInFrame
        self.ctLine = ctLine
        self.sourceOffset = sourceOffset
        self.caretOffset = caretOffset
        self.notInSourcePositions = notInSourcePositions
    }

    public var indexInFrame: Int
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

    public func stringIndexFor(position: CGPoint, lastLine: Bool = true) -> Int {
        var previous = carets.first?.offset.x ?? 0
        for caret in carets where caret.edge.isTrailing {
            let offset = caret.offset.x
            let middle = CGFloat(0.5 * (offset + previous))
            if middle > position.x {
                return max(0, caret.positionInSource - 1)
            }
            previous = offset
        }

        if let position = carets.last?.positionInSource {
            if lastLine {
                return position
            }
            return max(0, position-1)
        }
        
        return 0
    }

    private func charsToSkip(_ index: Int) -> Int {
        notInSourcePositions.binarySearch(predicate: { elem -> Bool in
            index > elem
        }) ?? notInSourcePositions.count

    }
    public func fromSource(_ index: Int) -> Int {
        index + charsToSkip(index)
    }

    public func toSource(_ index: Int) -> Int {
        index - charsToSkip(index)
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

    var caretOffset: Int
    lazy public var carets: [Caret] = {
        var c = [Caret]()
        c.reserveCapacity(CTLineGetGlyphCount(ctLine) * 3)
        let y = frame.minY

        var currentNotInSource = 0
        let end = notInSourcePositions.count
        var value = notInSourcePositions.first
        var count = sourceOffset
        CTLineEnumerateCaretOffsets(ctLine) { [self] (offset, index, leading, _) in
            while currentNotInSource < end, let val = value, val < index {
                currentNotInSource += 1
                if currentNotInSource < end {
                    value = notInSourcePositions[currentNotInSource]
                }
            }
            let notInSource = value == index
            let inSource = !notInSource
            let caret = Caret(offset: CGPoint(x: self.frame.origin.x + CGFloat(offset), y: y), indexInSource: count, indexOnScreen: index, edge: leading ? .leading : .trailing, inSource: inSource, line: self.indexInFrame)
            c.append(caret)
            count += (!caret.inSource || caret.edge.isLeading) ? 0 : 1
        }

        for i in 0..<c.count / 2 {
            var lead = c[i * 2]
            var trail = c[i * 2 + 1]
            // L2R or R2L?
            if lead.edge.isTrailing && trail.edge.isLeading {
                // R2L!
                lead.direction = .rightToLeft
                lead.edge = .leading
                trail.edge = .trailing
                trail.direction = .rightToLeft
                c[i * 2] = lead
                c[i * 2 + 1] = trail
            }
        }

        if !c.isEmpty {
            c[0].positionInLine = .start
            c[c.count - 1].positionInLine = .end
        }
        return c
    }()

    public var runs: [CTRun] {
        CTLineGetGlyphRuns(ctLine) as! [CTRun]
    }

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    public func draw(_ context: CGContext, translate: Bool = true) {
        context.saveGState()
        context.textPosition = NSPoint()
        if translate {
            context.translateBy(x: frame.origin.x, y: frame.origin.y)
        }
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
                    context.saveGState()
                    context.setStrokeColor(color.cgColor)

                    let  y = CGFloat(roundf(Float(ascent / 3.0)))

                    context.move(to: CGPoint(x: offset, y: y))
                    context.addLine(to: CGPoint(x: offset + CGFloat(width), y: y))
                    context.strokePath()
                    context.restoreGState()
                }

                if let color = attributes[.underlineColor] as? NSColor,
                   let styleRaw = attributes[.underlineStyle] as? NSNumber {
                    let style = NSUnderlineStyle(rawValue: styleRaw.intValue)
                    if style != .single {
                        context.saveGState()
                        context.setStrokeColor(color.cgColor)

                        let y = -CGFloat(roundf(Float(descent)))

                        context.move(to: CGPoint(x: offset, y: y))
                        context.setLineWidth(1)
                        switch style {
                        case .patternDot:
                            context.setLineDash(phase: 0, lengths: [2, 2])
                        case .patternDash:
                            context.setLineDash(phase: 0, lengths: [4, 2])
                        case .patternDashDot:
                            context.setLineDash(phase: 0, lengths: [4, 2, 2, 2])
                        case .patternDashDotDot:
                            context.setLineDash(phase: 0, lengths: [4, 2, 2, 2, 2, 2])
                        case .thick:
                            context.setLineWidth(2)
                        default:
                            break
                        }
                        context.addLine(to: CGPoint(x: offset + CGFloat(width), y: y))
                        context.strokePath()
                        context.restoreGState()
                    }
                }

                if let delegateAttribute = attributes[kCTRunDelegateAttributeName as NSAttributedString.Key] {
                    context.saveGState()
                    let delegate: CTRunDelegate = delegateAttribute as! CTRunDelegate
                    let imageRunRef = CTRunDelegateGetRefCon(delegate)
                    let imageRunPtr = imageRunRef.assumingMemoryBound(to: ImageRunStruct.self)
                    let imageRun = imageRunPtr.pointee
                    let imageName = imageRun.image
                    guard let image = NSImage(named: imageName) else { continue }

                    var rect = CGRect(origin: CGPoint(x: offset + 1 + imageRun.offset.x, y: 4 + imageRun.offset.y), size: image.size)
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
                    context.restoreGState()
                }
            }

            offset += CGFloat(width)
        }

        // Done!
        context.restoreGState()
    }

    public var interlineFactor: CGFloat = 1.0

    private var _layer: CALayer?

    var layer: CALayer {
        if let layer = _layer {
            return layer
        }

        let layer = TextLineLayer(self)
        _layer = layer
        return layer
    }
}
