//
//  ResizableNode.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 06/10/2021.
//

import Foundation
import Combine
import BeamCore

class ResizableNode: ElementNode {

    var canBeResized = true {
        didSet {
            if !canBeResized {
                removeLayer("handle")
            } else {
                setupResizeHandleLayer()
            }
            invalidate()
        }
    }

    ///The main element's real size (image or video)
    var resizableElementContentSize = CGSize.zero

    var isResizing = false

    @OptionalClamped<Double>(0.0...1.0) var desiredWidthRatio = nil
    @OptionalClamped<Double>(0.0...1.0) var desiredHeightRatio = nil

    var initialDragImageSize: CGSize?
    var initialDragImageGlobalPosition: NSPoint?

    var visibleSize: CGSize {
        let computedWidth: CGFloat
        if let ratio = desiredWidthRatio {
            computedWidth = computeWidth(with: contentsWidth * CGFloat(ratio))
        } else {
            computedWidth = computeWidth(with: contentsWidth)
        }
        let width = computedWidth.isNaN ? 0 : computedWidth
        var computedHeight = (width / resizableElementContentSize.width) * resizableElementContentSize.height
        // swiftlint:disable:next empty_enum_arguments
        if case .embed(_, _, _) = element.kind {
            if let ratio = desiredHeightRatio {
                // scale embed by ratio when both height and width are defined
                computedHeight = width * CGFloat(ratio)
            } else {
                // fix height in place when no height is defined
                computedHeight = resizableElementContentSize.height
            }
        }
        let height = computedHeight.isNaN ? 0 : computedHeight
        return NSSize(width: width, height: height)
    }

    override var hover: Bool {
        didSet {
            if let handle = layers["handle"],
               let handleLayer = handle.layer as? CAShapeLayer {
                guard !isResizing else { return }
                handleLayer.opacity = hover ? 1.0 : 0.0
            }
            invalidate()
        }
    }

    override func updateLayout() {
        super.updateLayout()

        let position = CGPoint(x: contentsLead, y: contentsTop)
        let bounds = CGRect(origin: .zero, size: visibleSize)

        if let handle = layers["handle"], let handleLayer = handle.layer as? CAShapeLayer {
            let layerPosition = CGPoint(x: position.x + bounds.size.width + 6, y: position.y + bounds.size.height / 2)

            let handleBounds = CGRect(origin: layerPosition, size: CGSize(width: 12, height: 44))

            let handlePosition = CGPoint(x: layerPosition.x + 5, y: layerPosition.y)
            let handlePath = NSBezierPath()
            handlePath.move(to: handlePosition)
            handlePath.line(to: NSPoint(x: handlePosition.x, y: handlePosition.y + 44))

            handleLayer.path = handlePath.cgPath
            handleLayer.position = layerPosition
            handleLayer.bounds = handleBounds
        }
    }

    func setupResizeHandleLayer() {

        guard canBeResized else {
            return
        }
        let handleLayer = CAShapeLayer()
        handleLayer.lineWidth = 2
        handleLayer.lineCap = .round
        handleLayer.strokeColor = BeamColor.AlphaGray.cgColor
        handleLayer.bounds = CGRect.zero
        handleLayer.position = .zero
        handleLayer.zPosition = 2
        handleLayer.opacity = 0.0

        let handle = Layer(name: "handle", layer: handleLayer) { [weak self] info in
            if info.event.clickCount == 2 {
                guard let elementSize = self?.resizableElementContentSize else { return false }
                self?.desiredWidthRatio = self?.visibleSize.width == self?.smallestWidth(for: elementSize) ? 1.0 : 0.0
                self?.invalidateLayout(animated: true)
                return true
            }
            self?.initialDragImageGlobalPosition = info.globalPosition
            self?.initialDragImageSize = self?.visibleSize
            return true
        } up: { [weak self] _ in
            self?.initialDragImageGlobalPosition = nil
            self?.initialDragImageSize = nil
            self?.isResizing = false
            self?.updateElementRatio()

            return true
        } dragged: { [weak self] info in
            guard let initialPosition = self?.initialDragImageGlobalPosition else { return false }
            guard let initialSize = self?.initialDragImageSize else { return false }
            guard let contentsWidth = self?.contentsWidth else { return false }

            self?.isResizing = true
            let xTranslation = info.globalPosition.x - initialPosition.x
            let desiredWidth = initialSize.width + xTranslation
            self?.desiredWidthRatio = Double(desiredWidth / contentsWidth)
            self?.invalidateLayout(animated: false)
            return true
        } hovered: { hovered in
            handleLayer.strokeColor = hovered ? BeamColor.LightStoneGray.cgColor : BeamColor.AlphaGray.cgColor
            handleLayer.lineWidth = hovered ? 4.0 : 2.0
        }
        handle.cursor = NSCursor.resizeLeftRight
        addLayer(handle, origin: .zero)
    }

    private func invalidateLayout(animated: Bool) {
        if !animated {
            self.editor?.shouldDisableAnimationAtNextLayout = true
        }
        self.invalidateLayout()
    }

    private func smallestWidth(for contentSize: CGSize) -> CGFloat {
        let smallestPossibleHeight: CGFloat = 48.0
        let width = contentSize.width / contentSize.height * smallestPossibleHeight
        return width
    }

    private func computeWidth(with desiredWidth: CGFloat?) -> CGFloat {

        var computedWidth: CGFloat

        if let width = desiredWidth {
            let maxWidth = min(width, resizableElementContentSize.width)
            let minWidth = smallestWidth(for: resizableElementContentSize)

            computedWidth = maxWidth > contentsWidth ? contentsWidth : maxWidth
            computedWidth = width < minWidth ? minWidth : computedWidth
        } else {
            computedWidth = resizableElementContentSize.width > contentsWidth ? contentsWidth : resizableElementContentSize.width
        }

        return computedWidth
    }

    private func updateElementRatio() {
        switch element.kind {
        case .image(let uid, let sourceMetadata, _):
            element.kind = .image(
                uid,
                origin: sourceMetadata,
                displayInfos: MediaDisplayInfos(
                    height: Int(resizableElementContentSize.height),
                    width: Int(resizableElementContentSize.width),
                    displayRatio: desiredWidthRatio
                )
            )
        case .embed(let url, let sourceMetadata, _):
            element.kind = .embed(url, origin: sourceMetadata, displayRatio: desiredWidthRatio)
        default:
            break
        }
    }
}
