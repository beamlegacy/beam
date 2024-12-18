//
//  ImageNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/05/2021.
//

import Foundation
import BeamCore
import Macaw
import Lottie
import Combine

class ImageNode: ResizableNode {

    private let focusMargin = CGFloat(3)
    private let cornerRadius = CGFloat(3)
    private var imageVerticalOffset: CGFloat {
        isCollapsed ? 1 : 0
    }
    private var toggleButtonOrigin: CGPoint {
        CGPoint(
            x: availableWidth + childInset,
            y: contentsTop + 2
        )
    }

    override var selectionLayerPosY: CGFloat {
        selectedAlone ? -5 : super.selectionLayerPosY
    }

    override var selectionLayerHeight: CGFloat {
        if let height = layers["focus"]?.layer.frame.height, selectedAlone {
            return isCollapsed ? height + 1 : height + 6
        }
        return super.selectionLayerHeight
    }

    private var sourceImageLayer: CALayer?
    private var imageLayer: Layer?

    private var imageName: String?
    private var imageSourceURL: URL?

    private var geometryDescription: MediaContentGeometryDescription

    var lottieView: LottieAnimationView?

    private var toggleButtonBeamLayer: CollapseButtonLayer?

    var isCollapsed: Bool {
        didSet {
            guard isCollapsed != oldValue else { return }

            element.collapsed = isCollapsed
            configureCollapsed(isCollapsed)
            if let imageLayer = imageLayer {
                layoutCollapseExpand(contentLayer: imageLayer.layer, verticalOffset: imageVerticalOffset)
            }
            self.invalidateLayout()
        }
    }
    var isHoverCollapseExpandButton: Bool = false

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        self.isCollapsed = element.isProxy || element.collapsed

        let contentGeometry = MediaContentGeometry(
            sizePreferencesStorage: element,
            sizePreferencesPersistenceStrategy: .contentSize
        )

        geometryDescription = .image(sized: .zero)
        super.init(parent: parent, element: element, availableWidth: availableWidth, contentGeometry: contentGeometry)

        BeamFileDBManager.fileSaved
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileRecord in
                guard let self = self,
                      fileRecord.id == self.imageId
                else { return }
                if self.imageLayer == nil {
                    self.setupImage(width: availableWidth)
                }
            }.store(in: &scope)
        setupImage(width: availableWidth)
    }

    override func setBottomPaddings(withDefault: CGFloat = 0) {
        super.setBottomPaddings(withDefault: isCollapsed ? 2 : 14)
    }

    private var imageId: UUID? {
        switch element.kind {
        case .image(let id, _, _):
            return id
        default:
            Logger.shared.logError("ImageNode can only handle image elements, not \(element.kind)", category: .noteEditor)
            return nil
        }
    }

    private func setupImage(width: CGFloat) {
        guard let uid = imageId else { return }
        guard let imageRecord = try? editor?.data?.fileDBManager?.fetch(uid: uid) else {
            Logger.shared.logError("ImageNode unable to fetch image '\(uid)' from FileDB", category: .noteEditor)
            return
        }

        imageName = imageRecord.name

        if case .image(_, origin: let sourceMetadata, displayInfos: _) = self.element.kind,
           case .remote(let url) = sourceMetadata?.origin {
            imageSourceURL = url
        } else {
            imageSourceURL = URL(string: self.element.text.text)
        }

        contentsPadding = NSEdgeInsets(top: 0, left: contentsPadding.left + 4, bottom: isCollapsed ? 2 : 14, right: 4)

        setAccessibilityLabel("ImageNode")
        setAccessibilityRole(.textArea)

        setupFocusLayer()
        setupImageLayer(using: imageRecord, uid: uid, width: width)
        configureCollapsed(isCollapsed)
        if !element.isProxy {
            addToggleButton()
        }

        updateLayout()
        if let imageLayer = imageLayer {
            layoutFocus(contentLayer: imageLayer.layer)
        }
    }

    private func createImage(from imageRecord: BeamFileRecord, availableWidth: Double, scale: Double) -> NSImage? {
        switch imageRecord.type {
        case "image/svg+xml":
            guard let svgString = imageRecord.data.asString, case .image(_, _, let info) = element.kind, let size = info.size else { return nil }
            let svgNode = try? SVGParser.parse(text: svgString)
            return try? svgNode?.toNativeImage(size: Size(Double(size.width), Double(size.height)), scale: scale)
        default:
            return NSImage(data: imageRecord.data, availableWidth: availableWidth, scale: scale)
        }
    }

    private func setupImageLayer(using imageRecord: BeamFileRecord, uid: UUID, width: CGFloat) {
        let imageLayer: Layer

        if let animatedImageLayer = Layer.animatedImage(named: "image", imageData: imageRecord.data) {
            animatedImageLayer.layer.position = .zero
            imageLayer = animatedImageLayer
            geometryDescription = .image(sized: animatedImageLayer.bounds.size)
            contentGeometry.setGeometryDescription(geometryDescription)
        } else {
            let scale = NSScreen.main?.backingScaleFactor ?? 1
            
            guard let image = createImage(from: imageRecord, availableWidth: width, scale: scale) else {
                Logger.shared.logError("ImageNode unable to decode image '\(uid)' from FileDB", category: .noteEditor)
                return
            }

            let imageSize: CGSize

            let imgRect = NSRect(x: 0, y: 0, width: width, height: 0)
            if let imageRep = image.bestRepresentation(for: imgRect, context: nil, hints: nil) {
                imageSize = CGSize(width: Double(imageRep.pixelsWide)/scale, height: Double(imageRep.pixelsHigh)/scale)
            } else {
                imageSize = image.size
            }

            guard imageSize.width > 0, imageSize.width.isFinite,
                  imageSize.height > 0, imageSize.height.isFinite else {
                      Logger.shared.logError("Loaded Image '\(uid)' has invalid size \(imageSize)", category: .noteEditor)
                      return
                  }

            geometryDescription = .image(sized: imageSize)
            contentGeometry.setGeometryDescription(geometryDescription)
            imageLayer = Layer.image(named: "image", image: image, size: contentGeometry.displaySize)
        }

        imageLayer.mouseDown = { [weak self] mouseInfo -> Bool in
            guard let self = self, !self.element.isProxy else { return false }
            if self.isCollapsed {
                self.isCollapsed = false
                return true
            } else if mouseInfo.event.clickCount == 2 {
                self.isCollapsed = true
                return true
            }
            return false
        }

        imageLayer.layer.cornerRadius = cornerRadius
        imageLayer.layer.masksToBounds = true
        imageLayer.layer.zPosition = 1
        imageLayer.layer.contentsGravity = .resizeAspectFill
        imageLayer.layer.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor

        self.imageLayer = imageLayer
        addLayer(imageLayer, origin: .zero)
    }

    private func setupFocusLayer() {
        let borderLayer = CAShapeLayer()
        borderLayer.lineWidth = 5
        borderLayer.strokeColor = selectionColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.zPosition = 0
        borderLayer.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
        let focusLayer = Layer(name: "focus", layer: borderLayer)
        addLayer(focusLayer, origin: .zero)
    }

    private func setupSourceButtonLayer() {

        guard imageSourceURL != nil, let sourceImage = NSImage(named: "editor-url_big") else { return }
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
        sourceLayer.addDefaultCompositingFilter = false

        sourceLayer.hovered = { [weak self, sourceImageLayer] hover in
            guard let self = self, let sourceImage = NSImage(named: "editor-url_big") else { return }
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
            guard mouseInfo.event.clickCount == 1, let self = self else { return false }
            if let url = self.imageSourceURL {
                let inBackground = mouseInfo.event.modifierFlags.contains(.command)
                self.editor?.openURL(url, self.element, inBackground)
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
        let height = layers["focus"]?.layer.frame.height ?? 26.0
        return isCollapsed ? height : visibleSize.height
    }

    override func updateLayout() {
        super.updateLayout()
        guard let imageLayer = imageLayer else { return }

        layoutImageLayer()
        layoutCollapseExpand(contentLayer: imageLayer.layer, verticalOffset: imageVerticalOffset)
        layoutToggleButton()
        layoutFocus(contentLayer: imageLayer.layer)
    }

    override func updateColors() {
        super.updateColors()

        if let focusLayer = layers["focus"], let borderLayer = focusLayer.layer as? CAShapeLayer {
            borderLayer.strokeColor = selectionColor
        }

        updateFocus()
    }

    private func layoutImageLayer() {
        if let imageLayer = layers["image"] {
            let contentBounds = CGRect(origin: .zero, size: isCollapsed ? CGSize(width: 16, height: 16) : visibleSize)
            imageLayer.layer.bounds = contentBounds
            imageLayer.layer.position = CGPoint(x: contentPosition.x, y: isCollapsed ? contentPosition.y + imageVerticalOffset : contentPosition.y)

            if let source = layers["source"] {
                let margin: CGFloat = 6.0
                let size = source.layer.frame.size
                source.layer.frame.origin = CGPoint(x: contentsLead + visibleSize.width - margin - size.width, y: contentsTop + margin)
            }
        }
    }

    private func layoutFocus(contentLayer: CALayer) {
        if let focusLayer = layers["focus"], let borderLayer = focusLayer.layer as? CAShapeLayer {
            var focusBounds = contentLayer.bounds.insetBy(dx: -focusMargin / 2, dy: -focusMargin / 2)
            if isCollapsed, let textLayer = layers["collapsed-text"] {
                focusBounds.size.width += textLayer.layer.frame.width + 12
                focusBounds.size.height = textLayer.layer.frame.height + 9
            }
            let borderPath = NSBezierPath(roundedRect: focusBounds, xRadius: cornerRadius, yRadius: cornerRadius)
            borderLayer.path = borderPath.cgPath

            let offset = isCollapsed ? 3.0 : 0.0
            let focusOrigin = CGPoint(x: contentLayer.position.x - offset, y: contentLayer.frame.minY - offset - imageVerticalOffset)
            borderLayer.frame = CGRect(origin: focusOrigin, size: focusBounds.size)
            borderLayer.lineWidth = isCollapsed ? 0 : 5
            borderLayer.fillColor = tokenColor
        }
    }

    public override func updateElementCursor() {
        let containerLayer = isCollapsed ? layers["collapsed-text"]?.layer : layers["image"]?.layer
        let bounds = containerLayer?.bounds ?? .zero
        let offset = isCollapsed ? 20.0 : 0.0
        let cursorRect = NSRect(x: caretIndex == 0 ? -4 : (bounds.width + 2 + offset), y: -focusMargin, width: 2, height: bounds.height + focusMargin * 2)
        layoutCursor(cursorRect)
    }

    override func updateFocus() {
        guard let focusLayer = layers["focus"] else { return }
        focusLayer.layer.opacity = isFocused ? 1 : 0
        if isCollapsed, let collapsedText = layers["collapsed-text"], let textLayer = collapsedText.layer as? CATextLayer {
            let hover = collapsedText.hovering
            textLayer.string = buildCollapsedTitle(mouseInteractionType: hover && !isFocused ? .hovered : nil)
            let tintedImage = NSImage(named: "editor-url")?.fill(color: textColor.nsColor)
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
        let contentWidth = layers["focus"]?.frame.width ?? visibleSize.width

        if mouseInfo.position.x < contentWidth / 2 {
            focus(position: 0)
        } else {
            focus(position: 1)
        }
        dragMode = .select(0)
        return true
    }

    override var frontmostHover: Bool {
        didSet {
            if let source = layers["source"] {
                source.layer.opacity = frontmostHover ? 1.0 : 0.0
                if frontmostHover, let blur = CIFilter(name: "CIGaussianBlur") {
                    blur.name = "blur"
                    source.layer.backgroundFilters = [blur]
                } else {
                    source.layer.backgroundFilters = []
                }
            }

            toggleButtonBeamLayer?.layer.opacity = frontmostHover ? 1.0 : 0.0
        }
    }

    private func configureCollapsed(_ isCollapsed: Bool) {
        if isCollapsed {
            self.canBeResized = false
            self.removeLayer("source")
            let thumbnail = NSImage(named: "field-web")!
            self.setupCollapsedLayer(title: mediaName, thumbnailLayer: imageLayer, or: thumbnail)
            self.imageLayer?.layer.borderWidth = 1
        } else {
            self.cleanCollapsedLayer()
            self.canBeResized = true
            self.setupResizeHandleLayer()
            self.setupSourceButtonLayer()
            self.imageLayer?.layer.borderWidth = 0
        }
    }

    private func addToggleButton() {
        toggleButtonBeamLayer = CollapseButtonLayer(name: "toggle", isCollapsed: isCollapsed) { [weak self] isCollapsed in
            self?.isCollapsed = isCollapsed
        }

        toggleButtonBeamLayer?.layer.opacity = 0
        toggleButtonBeamLayer?.collapseText = NSLocalizedString("to Link", comment: "Embed collapse button label")
        toggleButtonBeamLayer?.expandText = NSLocalizedString("to Image", comment: "Embed expand button label")

        addLayer(toggleButtonBeamLayer!)
    }

    private func layoutToggleButton() {
        CATransaction.disableAnimations {
            toggleButtonBeamLayer?.layer.frame.origin = toggleButtonOrigin
            toggleButtonBeamLayer?.isCompact = (editor?.useCompactTrailingGutter ?? false)
        }
    }

    override func elementDidChange() {
        super.elementDidChange()

        isCollapsed = element.collapsed
    }

}

// MARK: - ImageNode + Layer
extension ImageNode {
    override var bulletLayerPositionY: CGFloat { 0 }
    override var indentLayerPositionY: CGFloat { 20 }
}

extension ImageNode: Collapsible {
    var mediaName: String {
        imageSourceURL?.absoluteString ?? imageName ?? "Image"
    }
    var mediaURL: URL? {
        imageSourceURL
    }
}
