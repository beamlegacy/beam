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
                setupResizeHandleLayer()
            }
            invalidate()
        }
    }

    var contentGeometry: MediaContentGeometry {
        didSet {
            if contentGeometry.resizableAxes != oldValue.resizableAxes {
                removeHandles()
                setupResizeHandleLayer()
            }

            if contentGeometry.displaySize != oldValue.displaySize {
                updateDisplaySize()
            }
        }
    }

    var isResizing = false

    var initialDragImageSize: CGSize?
    var initialDragImageGlobalPosition: NSPoint?

    var resizableAxes: ResponsiveType { contentGeometry.resizableAxes }
    var visibleSize: CGSize { contentGeometry.displaySize }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat, contentGeometry: MediaContentGeometry) {
        self.contentGeometry = contentGeometry

        super.init(parent: parent, element: element, availableWidth: availableWidth)

        self.contentGeometry.setContainerWidth(contentsWidth)
    }

    /// The reference area to position the resizing handles around.
    var resizableContentBounds: CGRect {
        CGRect(
            origin: CGPoint(x: contentsLead, y: contentsTop),
            size: visibleSize
        )
    }

    override var frontmostHover: Bool {
        didSet {
            if let handle = layers["handle_horizontal"],
               let handleLayer = handle.layer as? CAShapeLayer {
                guard !isResizing else { return }
                handleLayer.opacity = frontmostHover ? 1.0 : 0.0
            }

            if let handle = layers["handle_vertical"],
               let handleLayer = handle.layer as? CAShapeLayer {
                guard !isResizing else { return }
                handleLayer.opacity = frontmostHover ? 1.0 : 0.0
            }
            invalidate()
        }
    }
    //swiftlint:disable:next function_body_length
    override func updateLayout() {
        super.updateLayout()

        contentGeometry.setContainerWidth(contentsWidth)

        let bounds = resizableContentBounds

            switch resizableAxes {
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
        switch resizableAxes {
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
                return true
            }
            self?.initialDragImageGlobalPosition = info.globalPosition
            self?.initialDragImageSize = self?.visibleSize
            return true
        } up: { [weak self] _ in
            self?.initialDragImageGlobalPosition = nil
            self?.initialDragImageSize = nil
            self?.isResizing = false
            self?.contentGeometry.savePreferredDisplaySize()

            return true
        } dragged: { [weak self] info in
            guard let initialPosition = self?.initialDragImageGlobalPosition else { return false }
            guard let initialSize = self?.initialDragImageSize else { return false }

            self?.isResizing = true
            let xTranslation = info.globalPosition.x - initialPosition.x
            let preferredWidth = initialSize.width + xTranslation
            self?.contentGeometry.setPreferredDisplayWidth(preferredWidth)
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
                return true
            }
            self?.initialDragImageGlobalPosition = info.globalPosition
            self?.initialDragImageSize = self?.visibleSize
            return true
        } up: { [weak self] _ in
            self?.initialDragImageGlobalPosition = nil
            self?.initialDragImageSize = nil
            self?.isResizing = false
            self?.contentGeometry.savePreferredDisplaySize()
            return true
        } dragged: { [weak self] info in
            guard let initialPosition = self?.initialDragImageGlobalPosition else { return false }
            guard let initialSize = self?.initialDragImageSize else { return false }

            self?.isResizing = true
            let yTranslation = info.globalPosition.y - initialPosition.y
            let preferredHeight = initialSize.height + yTranslation
            self?.contentGeometry.setPreferredDisplayHeight(preferredHeight)
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

    private func updateDisplaySize() {
        if isResizing {
            editor?.shouldDisableAnimationAtNextLayout = true
        }
        invalidateLayout()
    }

}
