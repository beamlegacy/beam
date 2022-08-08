//
//  TextFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/03/2021.
//

import Foundation
import BeamCore

public class TextFrame {
    private init(ctFrame: CTFrame, position: NSPoint, attributedString: NSAttributedString, singleLineHeightFactor: CGFloat?) {
        self.ctFrame = ctFrame
        self.position = position
        self.attributedString = attributedString
        self.singleLineHeightFactor = singleLineHeightFactor
        layout()
    }

    public var attributedString: NSAttributedString

    public var singleLineHeightFactor: CGFloat?
    public var debug: Bool { lines.count > 1 }
    public var ctFrame: CTFrame
    public var position: NSPoint
    public var lines = [TextLine]()
    public var notInSourcePositions = [Int]()
    public var isComplete: Bool = false

    public var visibleRange: Range<Int> {
        let r = CTFrameGetVisibleStringRange(ctFrame)
        return r.location ..< r.location + r.length
    }

    public var path: CGPath {
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

    public var frame: NSRect {
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

    private func layout() {
        notInSourcePositions = [Int]()
        attributedString.enumerateAttribute((kCTRunDelegateAttributeName as NSAttributedString.Key), in: attributedString.wholeRange, options: [], using: { value, range, _ in
            if value != nil {
                notInSourcePositions.append(range.location)
            }
        })

        var sourceOffset = 0
        var caretOffset = 0

        let ctLines = (CTFrameGetLines(ctFrame) as! [CTLine])
        var lineOrigins = [CGPoint](repeating: CGPoint(), count: ctLines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &lineOrigins)

        var Y = CGFloat(0)
        Y += paragraphSpacingBefore
        var index = 0

        if let lastLine = ctLines.last {
            let range = CTLineGetStringRange(lastLine)
            isComplete = (range.location + range.length) == attributedString.length
        } else {
            isComplete = true
        }

        let lineCount = ctLines.count

        lines = ctLines.map {
            let cfRange = CTLineGetStringRange($0)
            let range = NSRange(location: cfRange.location, length: cfRange.length)
            let line = TextLine(indexInFrame: index, ctLine: $0, attributedString: attributedString, sourceOffset: sourceOffset, caretOffset: caretOffset, notInSourcePositions: notInSourcePositions)

            let textPos = lineOrigins[index]
            let x = textPos.x
            //let y = f.maxY - textPos.y + CGFloat(line.bounds.descent)

            let y = Y // + CGFloat(line.bounds.ascent)

            line.frame = NSRect(x: (position.x + x).rounded(.toNearestOrEven), y: (position.y + y).rounded(.toNearestOrEven), width: line.bounds.width.rounded(.up), height: line.bounds.height.rounded(.up))

            //if debug {
            //Logger.shared.logDebug("     line[\(i)] frame \(line.frame) (textPos \(textPos)")
            //}

            sourceOffset = line.carets.last?.positionInSource ?? sourceOffset
            caretOffset += line.carets.count
            let lowerBound = line.carets.first?.positionInSource ?? 0
            if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: lowerBound, longestEffectiveRange: nil, in: range) as? NSParagraphStyle {
                line.interlineFactor = lineCount == 1 ? (singleLineHeightFactor ?? paragraphStyle.lineHeightMultiple) : paragraphStyle.lineHeightMultiple
            }
            Y += (line.frame.height * line.interlineFactor).rounded(.up)

            index += 1
            return line
        }

        if debug {
            //            Logger.shared.logDebug("start layout for \(lines.count) lines")
        }

        if debug {
            //Logger.shared.logDebug("layout frame \(frame)")
        }
    }

    public func draw(_ context: CGContext) {
        if debug {
            //Logger.shared.logDebug("draw frame \(ctFrame)")
        }
        for line in lines {
            line.draw(context)
        }
    }

    lazy public var carets: [Caret] = {
        lines.flatMap { $0.carets }
    }()

    public var caretsCount: Int { carets.count }
    public func caretAt(_ index: Int) -> Caret {
        guard let lineIndex = lines.binarySearch(predicate: { line -> Bool in
            index > line.caretOffset + line.carets.count - 1
        }) else {
            Logger.shared.logError("out of bounds looking for caret \(index) out of \(caretsCount)", category: .noteEditor)
            // Return a fake caret to prevent a crash:
            return Caret(offset: .zero, indexInSource: 0, indexOnScreen: 0, edge: .leading, inSource: true, line: 0)
        }

        let line = lines[lineIndex]
        let actualIndex = index - line.caretOffset
        return line.carets[actualIndex]
    }

    public func caretForSourcePosition(_ index: Int) -> Caret? {
        guard let caretIndex = caretIndexForSourcePosition(index) else { return nil }
        return caretAt(caretIndex)
    }

    public func caretIndexForSourcePosition(_ index: Int) -> Int? {
        guard carets.last?.positionInSource != index else { return max(0, caretsCount - 1) }
        guard let firstCaret = carets.binarySearch(predicate: { $0.positionInSource < index }) else { return nil }
        for i in firstCaret..<carets.count {
            let caret = carets[i]
            guard caret.positionInSource == index else { return nil }
            if caret.edge.isLeading || !caret.inSource {
                return i
            }
        }
        return nil
    }

    public func position(before index: Int) -> Int {
        guard !lines.isEmpty, index > 0 else { return 0 }
        return previousCaret(for: index, in: carets)
    }

    public func position(after index: Int) -> Int {
        guard !lines.isEmpty else { return 0 }
        return nextCaret(for: index, in: carets)
    }

    public class func create(string: NSAttributedString, atPosition position: NSPoint, textWidth: CGFloat, singleLineHeightFactor: CGFloat?, maxHeight: CGFloat?) -> TextFrame {
        assert(textWidth != 0)
        var string = string
        if string.string.last == "\n" {
            let newString = NSMutableAttributedString(attributedString: string)
            newString.append(NSAttributedString(string: "\n"))
            string = newString
        }
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let pos = CGPoint(x: position.x.rounded(), y: position.y.rounded())
        let path = CGPath(rect: CGRect(origin: pos, size: CGSize(width: textWidth.rounded(), height: maxHeight ?? CGFloat.greatestFiniteMagnitude)), transform: nil)

        let frameAttributes: [String: Any] = [:]
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(),
                                             path,
                                             frameAttributes as CFDictionary)

        let f = TextFrame(ctFrame: frame, position: position, attributedString: string, singleLineHeightFactor: singleLineHeightFactor)
        return f
    }

    private var _layer: CALayer?
    var layerTree: CALayer {
        if let layer = _layer {
            return layer
        }

        let layer = TextFrameLayer(self)

        _layer = layer
        return layer
    }
}
