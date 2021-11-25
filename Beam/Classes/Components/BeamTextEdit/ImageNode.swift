//
//  ImageNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/05/2021.
//

import Foundation
import BeamCore
import AppKit
import Macaw
import Lottie

class ImageNode: ResizableNode {

    private let focusMargin = CGFloat(3)
    private let cornerRadius = CGFloat(3)

    private var sourceImageLayer: CALayer?
    private var imageLayer: Layer?

    private var imageName: String?
    private var imageSourceURL: URL?

    var lottieView: AnimationView?

    var isCollapsed: Bool {
        didSet {
            element.collapsed = isCollapsed
            configureCollapsed(isCollapsed)
            setupCollapseExpandLayer()
            self.invalidateLayout()
        }
    }
    var isHoverCollapseExpandButton: Bool = false

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        self.isCollapsed = element.collapsed
        super.init(parent: parent, element: element, availableWidth: availableWidth)
        setupImage(width: availableWidth ?? fallBackWidth)
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat?) {
        self.isCollapsed = element.collapsed
        super.init(editor: editor, element: element, availableWidth: availableWidth)
        setupImage(width: availableWidth ?? fallBackWidth)
    }

    private func setupImage(width: CGFloat) {
        var uid = UUID.null
        switch element.kind {
        case .image(let id, let displayInfos):
            uid = id
            desiredWidthRatio = displayInfos.displayRatio
        default:
            Logger.shared.logError("ImageNode can only handle image elements, not \(element.kind)", category: .noteEditor)
            return
        }
        guard let imageRecord = try? BeamFileDBManager.shared.fetch(uid: uid) else {
            Logger.shared.logError("ImageNode unable to fetch image '\(uid)' from FileDB", category: .noteEditor)
            return
        }

        imageName = imageRecord.name
        imageSourceURL = URL(string: self.element.text.text)

        contentsPadding = NSEdgeInsets(top: 4, left: contentsPadding.left + 4, bottom: 14, right: 4)

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)

        setupImageLayer(using: imageRecord, uid: uid, width: width)
        configureCollapsed(isCollapsed)
        setupFocusLayer()
        setupCollapseExpandLayer()
    }

    private func createImage(from imageRecord: BeamFileRecord) -> NSImage? {
        switch imageRecord.type {
        case "image/svg+xml":
            guard let svgString = imageRecord.data.asString, case .image(_, let info) = element.kind, let size = info.size else { return nil }
            let svgNode = try? SVGParser.parse(text: svgString)
            return try? svgNode?.toNativeImage(size: Size(Double(size.width), Double(size.height)), scale: NSScreen.main?.backingScaleFactor ?? 1)
        default:
            return NSImage(data: imageRecord.data)
        }
    }

    private func setupImageLayer(using imageRecord: BeamFileRecord, uid: UUID, width: CGFloat) {
        var imageLayer: Layer
        if let animatedImageLayer = Layer.animatedImage(named: "image", imageData: imageRecord.data) {
            animatedImageLayer.layer.position = .zero
            imageLayer = animatedImageLayer
            resizableElementContentSize = animatedImageLayer.bounds.size
        } else {
            guard let image = createImage(from: imageRecord) else {
                Logger.shared.logError("ImageNode unable to decode image '\(uid)' from FileDB", category: .noteEditor)
                return
            }

            let imgRect = NSRect(x: 0, y: 0, width: width, height: 0)
            if let imageRep = image.bestRepresentation(for: imgRect, context: nil, hints: nil) {
                resizableElementContentSize = CGSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
            } else {
                resizableElementContentSize = image.size
            }

            guard resizableElementContentSize.width > 0, resizableElementContentSize.width.isFinite,
                  resizableElementContentSize.height > 0, resizableElementContentSize.height.isFinite else {
                Logger.shared.logError("Loaded Image '\(uid)' has invalid size \(resizableElementContentSize)", category: .noteEditor)
                return
            }

            let height = (width / resizableElementContentSize.width) * resizableElementContentSize.height
            imageLayer = Layer.image(named: "image", image: image, size: CGSize(width: width, height: height))
        }

        imageLayer.mouseDown = { [weak self] _ -> Bool in
            guard let self = self else { return false }
            if self.isCollapsed {
                self.isCollapsed = false
                return true
            }
            return false
        }

        imageLayer.layer.cornerRadius = cornerRadius
        imageLayer.layer.masksToBounds = true
        imageLayer.layer.zPosition = 1
        imageLayer.layer.contentsGravity = .resizeAspect

        self.imageLayer = imageLayer
        setupImageLayer(imageLayer)
    }

    private func setupImageLayer(_ imageLayer: Layer) {
        imageLayer.layer.cornerRadius = cornerRadius
        imageLayer.layer.masksToBounds = true
        imageLayer.layer.zPosition = 1
        addLayer(imageLayer, origin: .zero)
    }

    private func setupFocusLayer() {
        let bounds = CGRect.zero
        let borderLayer = CAShapeLayer()
        borderLayer.lineWidth = 5
        borderLayer.strokeColor = selectionColor.cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.bounds = bounds
        borderLayer.position = .zero
        borderLayer.zPosition = 0
        let focusLayer = Layer(name: "focus", layer: borderLayer)
        addLayer(focusLayer, origin: .zero)
    }

    private func setupSourceButtonLayer() {

        guard imageSourceURL != nil else { return }
        guard let sourceImage = NSImage(named: "editor-url_big") else { return }
        sourceImage.isTemplate = true
        let tintedImage = sourceImage.fill(color: BeamColor.Corduroy.nsColor)

        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: CGSize(width: 22, height: 22)), xRadius: 4, yRadius: 4)

        //The global layer
        let globalLayer = CALayer()
        globalLayer.frame = NSRect(origin: .zero, size: CGSize(width: 22, height: 22))
        globalLayer.masksToBounds = true
        globalLayer.zPosition = 2

        //Set the mask to clip the blurred background
        let mask = CAShapeLayer()
        mask.frame = NSRect(origin: .zero, size: CGSize(width: 22, height: 22))
        mask.path = path.cgPath
        mask.fillColor = .black
        globalLayer.mask = mask

        // The rounded shape layer
        let shape = CAShapeLayer()
        shape.frame = NSRect(origin: .zero, size: CGSize(width: 22, height: 22))
        shape.name = "backgound"
        shape.path = path.cgPath

        shape.fillColor = BeamColor.Editor.sourceButtonBackground.cgColor
        shape.strokeColor = BeamColor.Editor.sourceButtonStroke.cgColor
        shape.lineWidth = 1
        shape.opacity = 0.7

        //The arrow image layer
        let sourceImageLayer = CALayer()
        sourceImageLayer.name = "source-image"
        sourceImageLayer.contents = tintedImage
        sourceImageLayer.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: sourceImage.size)
        sourceImageLayer.compositingFilter = "multiplyBlendMode"

        //Keep reference to the source image layer for easier update
        self.sourceImageLayer = sourceImageLayer

        shape.addSublayer(sourceImageLayer)
        globalLayer.addSublayer(shape)

        globalLayer.opacity = 0.0

        let sourceLayer = sourceButtonLayer(with: globalLayer, shape: shape)
        addLayer(sourceLayer, origin: .zero)
    }

    private func sourceButtonLayer(with caLayer: CALayer, shape: CAShapeLayer) -> Layer {
        let sourceLayer = Layer(name: "source", layer: caLayer)

        sourceLayer.hovered = { [sourceImageLayer] hover in
            guard let sourceImage = NSImage(named: "editor-url_big") else { return }
            sourceImage.isTemplate = true
            let tintedImage = sourceImage.fill(color: hover ? .white : BeamColor.Corduroy.nsColor)

            self.sourceImageLayer?.contents = tintedImage
            sourceImageLayer?.compositingFilter = hover ? nil : "multiplyBlendMode"

            shape.fillColor = hover ? BeamColor.Editor.sourceButtonBackgroundHover.cgColor : BeamColor.Editor.sourceButtonBackground.cgColor
        }

        sourceLayer.mouseDown = { [weak self] mouseInfo in
            guard mouseInfo.event.clickCount == 1 else { return false }
            if self?.imageSourceURL != nil {
                shape.opacity = 0.9
                return true
            }
            return false
        }

        sourceLayer.mouseUp = { [weak self] mouseInfo in
            guard mouseInfo.event.clickCount == 1 else { return false }
            if let url = self?.imageSourceURL {
                self?.editor?.state?.handleOpenUrl(url, note: self?.element.note, element: self?.element)
                shape.opacity = 0.7
                return true
            }
            return false
        }

        sourceLayer.cursor = .pointingHand
        return sourceLayer
    }

    override func updateRendering() -> CGFloat {
        updateFocus()
        return isCollapsed ? 26.0 : visibleSize.height
    }

    override func updateLayout() {
        super.updateLayout()
        if let imageLayer = layers["image"] {
            let position = CGPoint(x: contentsLead, y: isCollapsed ? contentsTop + 7 : contentsTop)
            let bounds = CGRect(origin: .zero, size: isCollapsed ? CGSize(width: 16, height: 16) : visibleSize)
            guard bounds != imageLayer.layer.bounds || position != imageLayer.layer.position else { return }
            imageLayer.layer.position = position
            imageLayer.layer.bounds = bounds

            if let source = layers["source"] {
                let margin: CGFloat = 6.0
                let size = source.layer.frame.size
                source.layer.frame.origin = CGPoint(x: contentsLead + visibleSize.width - margin - size.width, y: contentsTop + margin)
            }

            layoutCollapseExpand(contentLayer: imageLayer.layer)

            if let focusLayer = layers["focus"], let borderLayer = focusLayer.layer as? CAShapeLayer {
                var focusBounds = bounds.insetBy(dx: -focusMargin / 2, dy: -focusMargin / 2)
                var collaspsedAdjustedBounds: CGRect?
                if isCollapsed, let textLayer = layers["collapsed-text"] {
                    focusBounds.size.width += textLayer.layer.frame.width + 6
                    focusBounds.size.height = 27
                    collaspsedAdjustedBounds = bounds
                    collaspsedAdjustedBounds?.size.width += textLayer.layer.frame.width + 6
                    collaspsedAdjustedBounds?.size.height += textLayer.layer.frame.width + 6
                }
                let borderPath = NSBezierPath(roundedRect: focusBounds, xRadius: cornerRadius, yRadius: cornerRadius)
                borderLayer.path = borderPath.cgPath
                borderLayer.position = CGPoint(x: position.x + (collaspsedAdjustedBounds ?? bounds).size.width / 2, y: position.y + bounds.size.height / 2)
                borderLayer.bounds = focusBounds
                borderLayer.lineWidth = isCollapsed ? 0 : 5
                borderLayer.fillColor = isCollapsed ? BeamColor.Editor.linkActiveBackground.cgColor : NSColor.clear.cgColor
            }
        }
    }

    public override func updateElementCursor() {
        let containerLayer = isCollapsed ? layers["collapsed-text"]?.layer : layers["image"]?.layer
        let bounds = containerLayer?.bounds ?? .zero
        let offset = isCollapsed ? 20.0 : 0.0
        let cursorRect = NSRect(x: caretIndex == 0 ? -4 : (bounds.width + 2 + offset), y: isCollapsed ? -focusMargin + 7 : -focusMargin, width: 2, height: bounds.height + focusMargin * 2)
        layoutCursor(cursorRect)
    }

    override func updateFocus() {
        guard let focusLayer = layers["focus"] else { return }
        focusLayer.layer.opacity = isFocused ? 1 : 0
        if isCollapsed, let textLayer = layers["collapsed-text"]?.layer as? CATextLayer {
            let color = isFocused ? BeamColor.Editor.linkActive : BeamColor.Editor.link
            if let text = textLayer.string as? NSAttributedString {
                guard let mutable = text.mutableCopy() as? NSMutableAttributedString else { return }
                textLayer.string = mutable.addAttributes([.foregroundColor: color.cgColor])
            }
            let tintedImage = NSImage(named: "editor-url")?.fill(color: color.nsColor)
            textLayer.sublayers?.first?.contents = tintedImage
        }
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        if mouseInfo.position.x < resizableElementContentSize.width / 2 {
            focus(position: 0)
        } else {
            focus(position: 1)
        }
        dragMode = .select(0)
        return true
    }

    override var hover: Bool {
        didSet {
            if let source = layers["source"] {
                source.layer.opacity = hover ? 1.0 : 0.0

                if hover, let blur = CIFilter(name: "CIGaussianBlur") {
                    blur.name = "blur"
                    source.layer.backgroundFilters = [blur]
                } else {
                    source.layer.backgroundFilters = []
                }
            }
            invalidate()
            super.hover = hover
        }
    }

    private func configureCollapsed(_ isCollapsed: Bool) {
        if isCollapsed {
            self.canBeResized = false
            self.layers["source"]?.layer.removeFromSuperlayer()
            let thumbnail = NSImage(named: "field-web")!
            self.setupCollapsedLayer(title: mediaName, thumbnailLayer: imageLayer, or: thumbnail)
        } else {
            self.cleanCollapsedLayer()
            self.canBeResized = true
            self.setupResizeHandleLayer()
            self.setupSourceButtonLayer()
        }
    }
}

// MARK: - ImageNode + Layer
extension ImageNode {
    override var bulletLayerPositionY: CGFloat { 9 }

    override var indentLayerPositionY: CGFloat { 28 }
}

extension ImageNode: Collapsable {

    var mediaName: String {
        imageSourceURL?.absoluteString ?? imageName ?? "Image"
    }

    var mediaURL: URL? {
        imageSourceURL
    }
}
