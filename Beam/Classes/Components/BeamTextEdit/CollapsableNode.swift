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
    var tokenColor: CGColor { get }
    var textColor: BeamColor { get }

    //The position for the content layer
    var contentPosition: CGPoint { get }

    func setupCollapsedLayer(title: String, thumbnailLayer: Layer?, or thumbnailImage: NSImage?)
    func setupCollapseExpandLayer(hidden: Bool)
    func cleanCollapsedLayer()

    func buildCollapsedTitle(mouseInteractionType: MouseInteractionType?) -> NSAttributedString
    func layoutCollapseExpand(contentLayer: CALayer, verticalOffset: CGFloat)
}

extension Collapsable where Self: ElementNode {

    var tokenColor: CGColor {
        guard isCollapsed else { return NSColor.clear.cgColor }
        let tokenColor = mediaURL != nil ? BeamColor.Editor.linkActiveBackground.cgColor : BeamColor.Editor.tokenNoLinkActiveBackground.cgColor
        return tokenColor
    }

    var textColor: BeamColor {
        let activeTextColor = mediaURL != nil ? BeamColor.Editor.linkActive : BeamColor.Editor.link
        return isFocused ? activeTextColor : BeamColor.Editor.link
    }

    var contentPosition: CGPoint {
        CGPoint(x: contentsLead, y: contentsTop)
    }

    func setupCollapsedLayer(title: String, thumbnailLayer: Layer?, or thumbnailImage: NSImage?) {
        guard isCollapsed else {
            return
        }
        let initialColor = BeamColor.Editor.link.nsColor

        let thumbnailWidth = 16.0
        let thumbnailLayer = thumbnailLayer ?? Layer.image(named: "thumbnail", image: thumbnailImage!, size: CGSize(width: thumbnailWidth, height: thumbnailWidth))
        thumbnailLayer.frame.size = CGSize(width: thumbnailWidth, height: thumbnailWidth)
        thumbnailLayer.frame.origin = contentPosition

        let text = Layer.text(named: "collapsed-text", title, color: initialColor, size: PreferencesManager.editorFontSize)
        text.cursor = .pointingHand
        text.frame.origin =  CGPoint(x: thumbnailLayer.layer.position.x + thumbnailWidth + 6, y: 0)

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

        text.hovered = { [weak self] hover in
            guard let self = self, let collapsedText = self.layers["collapsed-text"], let textLayer = collapsedText.layer as? CATextLayer else { return }
            textLayer.string = self.buildCollapsedTitle(mouseInteractionType: hover && !self.isFocused ? .hovered : .unknown)
        }

        if thumbnailLayer.layer.superlayer == nil {
            addLayer(thumbnailLayer, origin: CGPoint(x: thumbnailLayer.layer.frame.width, y: 0))
        }
        addLayer(text, origin: CGPoint(x: thumbnailLayer.layer.position.x + thumbnailWidth + 6, y: 0))
    }

    func setupCollapseExpandLayer(hidden: Bool) {

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
        globalLayer.opacity = hidden ? 0.0 : 1.0

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
        let config = BeamTextAttributedStringBuilder.Config(elementKind: .bullet, ranges: text.ranges, fontSize: PreferencesManager.editorFontSize, fontColor: BeamColor.Generic.text.staticColor, markedRange: nil, searchedRanges: [], mouseInteraction: mouseInteraction)

        let builtString = builder.build(config: config).addAttributes([.foregroundColor: textColor.cgColor]).addAttributes([.font: BeamFont.regular(size: 14).nsFont])
        return builtString
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

        let title = isCollapsed ? "To Expanded" : collapsedTitle
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.foregroundColor = color.cgColor
        textLayer.fontSize = 12
        textLayer.font = BeamFont.medium(size: 12).nsFont
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

    func layoutCollapseExpand(contentLayer: CALayer, verticalOffset: CGFloat) {
        if let textLayer = layers["collapsed-text"]?.layer as? CATextLayer {

            let text = buildCollapsedTitle(mouseInteractionType: nil)
            let boundingRect = text.boundingRect(with: NSSize(width: contentsWidth, height: 0), options: .usesLineFragmentOrigin)
            textLayer.string = text
            let origin = CGPoint(x: contentLayer.position.x + contentLayer.frame.width + 6, y: contentLayer.frame.minY - verticalOffset)
            textLayer.frame.origin = origin
            let frame = TextFrame.create(string: text, atPosition: origin, textWidth: contentsWidth, singleLineHeightFactor: nil, maxHeight: nil)

            textLayer.truncationMode = .end
            textLayer.isWrapped = true
            textLayer.frame.size = boundingRect.size

            if let arrow = textLayer.sublayers?.first,
               let lastLine = frame.lines.last {
                let caretsCount = frame.carets.count
                let imageCarret = frame.carets[caretsCount - 2]

                arrow.frame.origin = CGPoint(x: imageCarret.offset.x - lastLine.frame.origin.x, y: imageCarret.offset.y - 5)
            }
        }

        if let expandButtonLayer = layers["global-expand"]?.layer,
           let textLayer = expandButtonLayer.sublayers?.first(where: {$0 is CATextLayer}) as? CATextLayer {
            let margin: CGFloat = 11.0
            expandButtonLayer.frame.origin = CGPoint(x: availableWidth + childInset + margin, y: contentsTop + 2)

            let title = isCollapsed ? "to Image" : collapsedTitle
            textLayer.string = title
            let size = textLayer.preferredFrameSize()
            textLayer.frame.size = size
        }
    }

    var collapsedTitle: String {
        return mediaURL != nil ? "to Link" : "Collapse"
    }
}
