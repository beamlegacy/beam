//
//  CollapsableNode.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 09/11/2021.
//

import Foundation
import AppKit
import Lottie
import BeamCore

protocol Collapsable: AnyObject {
    var isCollapsed: Bool { get set }
    var isHoverCollapseExpandButton: Bool { get set }

    var mediaName: String { get }
    var mediaURL: URL? { get }

    var lottieView: AnimationView? { get set }

    func setupCollapsedLayer(title: String, thumbnailLayer: Layer?, or thumbnailImage: NSImage?)
    func setupCollapseExpandLayer()
    func cleanCollapsedLayer()

    func buildCollapsedTitle(mouseInteractionType: MouseInteractionType?) -> NSAttributedString
    func layoutCollapseExpand(contentLayer: CALayer)
}

extension Collapsable where Self: ElementNode {

    func setupCollapsedLayer(title: String, thumbnailLayer: Layer?, or thumbnailImage: NSImage?) {
        guard isCollapsed else {
            return
        }

        let initialColor = BeamColor.Editor.link.nsColor
        let thumbnailLayer = thumbnailLayer ?? Layer.image(named: "thumbnail", image: thumbnailImage!, size: CGSize(width: 16, height: 16))
        let text = Layer.text(named: "collapsed-text", title, color: initialColor, size: PreferencesManager.editorFontSize)
        text.layer.opacity = 0

        if mediaURL != nil {
            let linkImageLayer = CALayer()
            let tintedImage = NSImage(named: "editor-url")?.fill(color: initialColor)
            linkImageLayer.contents = tintedImage
            linkImageLayer.frame.size  = CGSize(width: 10, height: 10)
            text.layer.addSublayer(linkImageLayer)
        }

        text.mouseDown = { [weak self ] _ -> Bool in
            if let url = self?.mediaURL {
                let element = self?.element
                let note = element?.note

                self?.editor?.state?.handleOpenUrl(url, note: note, element: element)
                return true
            }
            return false
        }

        text.hovered = { hover in
            guard let collapsedText = self.layers["collapsed-text"], let textLayer = collapsedText.layer as? CATextLayer else { return }
            textLayer.string = self.buildCollapsedTitle(mouseInteractionType: hover ? .hovered : .unknown)
        }

        addLayer(thumbnailLayer, origin: CGPoint(x: thumbnailLayer.layer.frame.width, y: 0))
        addLayer(text, origin: CGPoint(x: thumbnailLayer.layer.position.x + thumbnailLayer.layer.frame.width + 6, y: 0))

        text.layer.opacity = 1
    }

    func setupCollapseExpandLayer() {

        let hoverColor = isHoverCollapseExpandButton ? BeamColor.Editor.collapseExpandButtonHover : BeamColor.Editor.collapseExpandButton

        guard let layer = buildLottieLayer() else { return }
        let textLayer = buildCollapseExpandTextLayer(color: hoverColor)

        let globalLayer = CALayer()
        let globalWidth = layer.frame.width + 4 + textLayer.frame.width
        globalLayer.frame = CGRect(x: 0, y: 0, width: globalWidth, height: layer.frame.width)

        let global = Layer(name: "global-expand", layer: globalLayer)
        globalLayer.addSublayer(layer)
        globalLayer.addSublayer(textLayer)
        textLayer.frame.origin = CGPoint(x: 15, y: -1)

        configureMouseInteraction(for: global)

        addLayer(global)
    }

    func cleanCollapsedLayer() {
        self.removeLayer("collapsed-text")
        self.removeLayer("thumbnail")
    }

    func buildCollapsedTitle(mouseInteractionType: MouseInteractionType?) -> NSAttributedString {
        let builder = BeamTextAttributedStringBuilder()
        var text = BeamText(attributedString: NSAttributedString(string: mediaName))
        if let url = mediaURL {
            text.addAttributes([.link(url.absoluteString)], to: 0..<mediaName.count)
        }

        let mouseInteraction = MouseInteraction(type: mouseInteractionType ?? .unknown, range: NSRange(location: 0, length: text.count))
        let config = BeamTextAttributedStringBuilder.Config(elementKind: .bullet, ranges: text.ranges, fontSize: PreferencesManager.editorFontSize, markedRange: nil, searchedRanges: [], mouseInteraction: mouseInteraction)

        let buildedString = builder.build(config: config)
        return buildedString
    }

    private func buildLottieLayer() -> CALayer? {
        lottieView = AnimationView(name: isCollapsed ? "editor-embed_expand" : "editor-embed_collapse" )
        setLottieViewColor(color: BeamColor.Editor.collapseExpandButton.nsColor)
        lottieView?.loopMode = .playOnce

        guard let layer = lottieView?.animationLayer else { return nil }
        layer.removeFromSuperlayer()
        layer.frame.origin = .zero

        return layer
    }

    private func setLottieViewColor(color: NSColor) {
        if let color = color.usingColorSpace(NSScreen.main?.colorSpace ?? .sRGB) {
            let colorProvider = ColorValueProvider(Color(r: color.redComponent, g: color.greenComponent, b: color.blueComponent, a: 1))
            let fillKeypath = AnimationKeypath(keypath: "**.Fill 1.Color")
            self.lottieView?.setValueProvider(colorProvider, keypath: fillKeypath)
        }
    }

    private func buildCollapseExpandTextLayer(color: BeamColor) -> CATextLayer {

        let title = isCollapsed ? "To Expanded" : "To Link"
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.foregroundColor = color.cgColor
        textLayer.fontSize = 12
        textLayer.font = BeamFont.regular(size: 12).nsFont
        textLayer.frame.size = textLayer.preferredFrameSize()
        textLayer.opacity = isHoverCollapseExpandButton ? 1.0 : 0.0

        return textLayer
    }

    private func configureMouseInteraction(for layer: Layer) {

        let mouseDown: (MouseInfo) -> Bool = { [weak self] _ in
            guard let collapseExpand = self?.layers["global-expand"],
                  let textLayer = collapseExpand.layer.sublayers?[1] as? CATextLayer else { return false }
            let mouseDownColor = BeamColor.Editor.collapseExpandButtonClicked
            textLayer.foregroundColor = mouseDownColor.cgColor
            self?.setLottieViewColor(color: mouseDownColor.nsColor)
            return true
        }

        let mouseUp: (MouseInfo) -> Bool = { [weak self] _ -> Bool in
            guard let collapseExpand = self?.layers["global-expand"],
                  let textLayer = collapseExpand.layer.sublayers?[1] as? CATextLayer else { return false }
            self?.isCollapsed.toggle()

            let upColor = BeamColor.Editor.collapseExpandButtonHover
            textLayer.foregroundColor = upColor.cgColor
            self?.setLottieViewColor(color: upColor.nsColor)

            return true
        }

        let mouseHover: (Bool) -> Void = { [weak self] isHover in
            guard let collapseExpand = self?.layers["global-expand"],
                  let textLayer = collapseExpand.layer.sublayers?[1] as? CATextLayer else { return }
            textLayer.opacity = isHover ? 1.0 : 0.0
            let hoverColor = isHover ? BeamColor.Editor.collapseExpandButtonHover : BeamColor.Editor.collapseExpandButton

            textLayer.foregroundColor = hoverColor.cgColor
            self?.setLottieViewColor(color: hoverColor.nsColor)
            self?.isHoverCollapseExpandButton = isHover

            if isHover {
                self?.lottieView?.play(completion: nil)
            }
        }

        layer.mouseUp = mouseUp
        layer.mouseDown = mouseDown
        layer.hovered = mouseHover
    }

    func layoutCollapseExpand(contentLayer: CALayer) {
        if let textLayer = layers["collapsed-text"]?.layer as? CATextLayer {
            textLayer.string = buildCollapsedTitle(mouseInteractionType: nil)
            textLayer.frame.origin = CGPoint(x: contentLayer.position.x + contentLayer.frame.width + 6, y: contentLayer.frame.midY - textLayer.frame.height / 2)
            let size = textLayer.preferredFrameSize()
            textLayer.frame.size = size
            if let arrow = textLayer.sublayers?.first {
                let arrowWidth = arrow.frame.width
                arrow.frame.origin = CGPoint(x: size.width - arrowWidth, y: -1)
            }
        }

        if let expandButtonLayer = layers["global-expand"]?.layer,
           let textLayer = expandButtonLayer.sublayers?.first(where: {$0 is CATextLayer}) as? CATextLayer {
            let margin: CGFloat = 15.0
            expandButtonLayer.frame.origin = CGPoint(x: availableWidth + margin, y: contentsTop + 10)

            let title = isCollapsed ? "to Image" : "to Link"
            textLayer.string = title
            let size = textLayer.preferredFrameSize()
            textLayer.frame.size = size
        }
    }
}
