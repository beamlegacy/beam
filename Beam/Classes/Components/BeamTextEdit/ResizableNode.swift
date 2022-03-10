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
                removeHandles()
            } else {
                setupContentSizing()
                setupResizeHandleLayer()
            }
            invalidate()
        }
    }

    ///The main element's real size (image or video)
    var resizableElementContentSize = CGSize.zero {
        didSet {
            let widthRatio = (desiredWidthRatio ?? 1.0)
            let initWidth = contentsWidth * widthRatio
            setVisibleWidth(initWidth)

            if !keepAspectRatio, visibleSize.height == 0 {
                visibleSize.height = resizableElementContentSize.height.clamp(minHeight, maxHeight)
            }
        }
    }

    /// Scaling ratio of Node
    @OptionalClamped<Double>(0.001...1.0) var desiredWidthRatio = 1.0

    var isResizing = false

    var initialDragImageSize: CGSize?
    var initialDragImageGlobalPosition: NSPoint?

    var fallBackWidth: CGFloat {
        let fullWidth = BeamTextEdit.textNodeWidth(for: editor?.frame.size ?? .zero) - childInset
        let embedWidth = (fullWidth - contentsLead)
        return embedWidth
    }

    var minWidth: CGFloat = 48
    var minHeight: CGFloat = 48
    var maxWidth: CGFloat?
    var maxHeight: CGFloat = 2200
    var keepAspectRatio: Bool = true
    var responsiveStrategy: ResponsiveType? {
        didSet {
            setupResizeHandleLayer()
        }
    }
    var visibleSize: CGSize = .zero

    /// The reference area to position the resizing handles around.
    var resizableContentBounds: CGRect {
        CGRect(
            origin: CGPoint(x: contentsLead, y: contentsTop),
            size: visibleSize
        )
    }

    func setVisibleSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        switch responsiveStrategy {
        case .horizontal:
            setVisibleWidth(width)
        case .vertical:
            setVisibleHeight(height)
        default:
            setVisibleWidth(width)
            setVisibleHeight(height)
        }
    }

    func setVisibleWidth(_ width: CGFloat? = nil) {
        guard let width = width else { return }
        // clamp the maximum width at the maxWidth of the element or
        //at the fallBackWidth which ever is smallest
        let maxWidthClamp = min(maxWidth ?? fallBackWidth, fallBackWidth)
        let clampedWidth = width.clamp(minWidth, maxWidthClamp)
        visibleSize.width = clampedWidth

        if keepAspectRatio {
            let originalAspectRatio = resizableElementContentSize.aspectRatio
            let computedHeight = clampedWidth * originalAspectRatio
            visibleSize.height = computedHeight.clamp(minHeight, maxHeight)
        }
    }

    func setVisibleHeight(_ height: CGFloat? = nil) {
        guard let height = height else { return }

        if keepAspectRatio {
            let originalAspectRatio = resizableElementContentSize.width / resizableElementContentSize.height
            let computedWidth = height * originalAspectRatio
            // clamp the maximum width at the maxWidth of the element or
            //at the fallBackWidth which ever is smallest
            let maxWidthClamp = min(maxWidth ?? fallBackWidth, fallBackWidth)
            visibleSize.width = computedWidth.clamp(minWidth, maxWidthClamp)

            let computedMaxHeight = visibleSize.width / originalAspectRatio
            let maxHeightClamp = min(maxHeight, computedMaxHeight)
            visibleSize.height = height.clamp(minHeight, maxHeightClamp)
        } else {
            visibleSize.height = height.clamp(minHeight, maxHeight)
        }
    }

    override var hover: Bool {
        didSet {
            if let handle = layers["handle_horizontal"],
               let handleLayer = handle.layer as? CAShapeLayer {
                guard !isResizing else { return }
                handleLayer.opacity = hover ? 1.0 : 0.0
            }

            if let handle = layers["handle_vertical"],
               let handleLayer = handle.layer as? CAShapeLayer {
                guard !isResizing else { return }
                handleLayer.opacity = hover ? 1.0 : 0.0
            }
            invalidate()
        }
    }
    //swiftlint:disable:next function_body_length
    override func updateLayout() {
        super.updateLayout()

        let bounds = resizableContentBounds

            switch responsiveStrategy {
            case .horizontal:
                if let handle = layers["handle_horizontal"], let handleLayer = handle.layer as? CAShapeLayer {
                    let layerPosition = CGPoint(x: bounds.minX + bounds.size.width + 6, y: bounds.minY + bounds.size.height / 2)

                    let handleBounds = CGRect(origin: layerPosition, size: CGSize(width: 12, height: 44))

                    let handlePosition = CGPoint(x: layerPosition.x + 5, y: layerPosition.y)
                    let handlePath = NSBezierPath()
                    handlePath.move(to: handlePosition)
                    handlePath.line(to: NSPoint(x: handlePosition.x, y: handlePosition.y + 44))

                    handleLayer.path = handlePath.cgPath
                    handleLayer.position = layerPosition
                    handleLayer.bounds = handleBounds
                }
            case .vertical:
                if let handle = layers["handle_vertical"], let handleLayer = handle.layer as? CAShapeLayer {
                    let layerPosition = CGPoint(x: bounds.minX + bounds.size.width / 2, y: bounds.minY + bounds.size.height)

                    let handleBounds = CGRect(origin: layerPosition, size: CGSize(width: 44, height: 12))

                    let handlePosition = CGPoint(x: layerPosition.x, y: layerPosition.y + 5)
                    let handlePath = NSBezierPath()
                    handlePath.move(to: handlePosition)
                    handlePath.line(to: NSPoint(x: handlePosition.x + 44, y: handlePosition.y))

                    handleLayer.path = handlePath.cgPath
                    handleLayer.position = layerPosition
                    handleLayer.bounds = handleBounds
                }
            case .both:
                if let handle = layers["handle_horizontal"], let handleLayer = handle.layer as? CAShapeLayer {
                    let layerPosition = CGPoint(x: bounds.minX + bounds.size.width + 6, y: bounds.minY + bounds.size.height / 2)

                    let handleBounds = CGRect(origin: layerPosition, size: CGSize(width: 12, height: 44))

                    let handlePosition = CGPoint(x: layerPosition.x + 5, y: layerPosition.y)
                    let handlePath = NSBezierPath()
                    handlePath.move(to: handlePosition)
                    handlePath.line(to: NSPoint(x: handlePosition.x, y: handlePosition.y + 44))

                    handleLayer.path = handlePath.cgPath
                    handleLayer.position = layerPosition
                    handleLayer.bounds = handleBounds
                }

                if let handle = layers["handle_vertical"], let handleLayer = handle.layer as? CAShapeLayer {
                    let layerPosition = CGPoint(x: bounds.minX + bounds.size.width / 2, y: bounds.minY + bounds.size.height + 6)

                    let handleBounds = CGRect(origin: layerPosition, size: CGSize(width: 44, height: 12))

                    let handlePosition = CGPoint(x: layerPosition.x, y: layerPosition.y + 5)
                    let handlePath = NSBezierPath()
                    handlePath.move(to: handlePosition)
                    handlePath.line(to: NSPoint(x: handlePosition.x + 44, y: handlePosition.y))

                    handleLayer.path = handlePath.cgPath
                    handleLayer.position = layerPosition
                    handleLayer.bounds = handleBounds
                }
            case .none:
                return
            }
    }

    func setupResizeHandleLayer() {
        switch responsiveStrategy {
        case .horizontal:
            setupHorizontalResizeHandleLayer()
        case .vertical:
            setupVerticalResizeHandleLayer()
        case .both:
            setupHorizontalResizeHandleLayer()
            setupVerticalResizeHandleLayer()
        case .none:
            return
        }
    }

    func setupContentSizing() {
        switch element.kind {
        case .image(_, _, let displayInfo):
            if let ratio = displayInfo.displayRatio {
                self.desiredWidthRatio = ratio
            }

            if let width = displayInfo.width {
                self.resizableElementContentSize.width = CGFloat(width)
            }

            if let height = displayInfo.height {
                self.resizableElementContentSize.height = CGFloat(height)
            }
        case .embed(_, _, let displayInfo):
            if let widthRatio = displayInfo.displayRatio, let height = displayInfo.height {
                desiredWidthRatio = widthRatio
                resizableElementContentSize = CGSize(
                    width: Int(contentsWidth * widthRatio),
                    height: height
                )
            } else {
                resizableElementContentSize = EmbedNode.initialExpandedContentSize
            }
        default:
            break
        }
    }

    func setupHorizontalResizeHandleLayer() {
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

        let handle = Layer(name: "handle_horizontal", layer: handleLayer) { [weak self] info in
            if info.event.clickCount == 2 {
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
            self?.setVisibleSize(width: desiredWidth)
            self?.invalidateLayout(animated: false)
            return true
        } hovered: { hovered in
            handleLayer.strokeColor = hovered ? BeamColor.LightStoneGray.cgColor : BeamColor.AlphaGray.cgColor
            handleLayer.lineWidth = hovered ? 4.0 : 2.0
        }
        handle.cursor = NSCursor.resizeLeftRight
        addLayer(handle, origin: .zero)
    }

    private func setupVerticalResizeHandleLayer() {
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

        let handle = Layer(name: "handle_vertical", layer: handleLayer) { [weak self] info in
            if info.event.clickCount == 2 {
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

            self?.isResizing = true
            let yTranslation = info.globalPosition.y - initialPosition.y
            let desiredHeight = initialSize.height + yTranslation
            self?.setVisibleSize(height: desiredHeight)
            self?.invalidateLayout(animated: false)
            return true
        } hovered: { hovered in
            handleLayer.strokeColor = hovered ? BeamColor.LightStoneGray.cgColor : BeamColor.AlphaGray.cgColor
            handleLayer.lineWidth = hovered ? 4.0 : 2.0
        }
        handle.cursor = NSCursor.resizeUpDown
        addLayer(handle, origin: .zero)
    }

    private func removeHandles() {
        removeLayer("handle_vertical")
        removeLayer("handle_horizontal")
    }

    private func invalidateLayout(animated: Bool) {
        if !animated {
            self.editor?.shouldDisableAnimationAtNextLayout = true
        }
        self.invalidateLayout()
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
            /// DisplayInfo explainer for embeds:
            /// - The width is always expressed as a ratio to the available editor width stored in displayInfo.displayRatio (at least on the client)
            /// - The height is always expressed as an absolute number of pixels stored in displayinfo.height
            /// - displayinfo.width is not used for embeds
            ///
            /// Should the embed have the preserveAspectRatio flag, the displayInfo.height will be ignored
            /// to instead respect the aspect ratio, based on the width of the embed
            element.kind = .embed(
                url,
                origin: sourceMetadata,
                displayInfos: MediaDisplayInfos(
                    height: Int(visibleSize.height),
                    displayRatio: visibleSize.width / contentsWidth
                )
            )
        default:
            break
        }
    }
}
