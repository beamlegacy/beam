import Foundation
import Combine
import AppKit
import BeamCore

class ReferencesSection: LinksSection {
    var linkLayer: Layer?

    let linkActionLayer = CATextLayer()
    override var openChildrenDefault: Bool { false }

    override var open: Bool {
        didSet {
            linkLayer?.layer.isHidden = !open
        }
    }

    override func setupUI(openChildren: Bool) {
        layerFrameXPad = CGFloat(30)

        super.setupUI(openChildren: openChildren)

        linkActionLayer.font = BeamFont.medium(size: 0).nsFont
        linkActionLayer.fontSize = 12
        linkActionLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkActionLayer.contentsScale = contentsScale
        linkActionLayer.alignmentMode = .center
        linkActionLayer.string = "Link All"
    }

    override var links: [BeamNoteReference] { note.references }

    override func setupSectionMode() {
        super.setupSectionMode()
        createLinkAllLayer()
    }

    override func updateHeading(_ count: Int) {
        sectionTitleLayer.string = "reference".localizedStringWith(comment: "reference section title", count)
        selfVisible = !children.isEmpty
        visible = selfVisible
        sectionTitleLayer.isHidden = !selfVisible
        separatorLayer.isHidden = !selfVisible
    }

    override func shouldHandleReference(rootNote: String, rootNoteId: UUID, text: BeamText) -> Bool {
        let linksToNote = text.hasLinkToNote(id: rootNoteId)
        let referencesToNote = text.hasReferenceToNote(titled: rootNote)

        // This is subtle: we don't want hide nodes that have just been edited so that they are not a reference to this card anymore, so we make them disapear only if the became a link to the curent card. This only happens after the initial update as the initial update should filter out anything that is not a reference. It has the symetrical behaviour of LinksSection
        if initialUpdate {
            return !linksToNote && referencesToNote
        } else {
            return !linksToNote
        }
    }

    func createLinkAllLayer() {
        let linkContentLayer = CALayer()
        linkContentLayer.addSublayer(linkActionLayer)

        linkLayer = LinkButtonLayer(
            "linkAllLayer",
            linkContentLayer,
            activated: { [weak self] in
                guard let self = self,
                      let rootNote = self.editor.note.note else { return }

                if let linkLayer = self.linkLayer, linkLayer.layer.isHidden { return }

                for child in self.children {
                    guard let title = child as? RefNoteTitle else { continue }
                    title.makeLinksToNoteExplicit(forNote: rootNote.title)
                }
            }, hovered: {[weak self] isHover in
                guard let self = self else { return }

                self.linkActionLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
            })

        guard let linkLayer = linkLayer else { return }
        addLayer(linkLayer)
    }

    override func updateSubLayersLayout() {
        CATransaction.disableAnimations {
            setupLayerFrame()
            separatorLayer.frame = CGRect(x: 0, y: sectionTitleLayer.frame.maxY + 4, width: 560, height: 1)

            guard let linkAllLayer = linkLayer else { return }
            let linkActionLayerFrameSize = linkActionLayer.preferredFrameSize()

            linkAllLayer.frame = CGRect(origin: CGPoint(x: frame.width - linkActionLayerFrameSize.width, y: -3), size: NSSize(width: 54, height: 21))

            let linkActionLayerXPosition = linkAllLayer.bounds.width / 2 - linkActionLayerFrameSize.width / 2
            let linkActionLayerYPosition = linkAllLayer.bounds.height / 2 - linkActionLayerFrameSize.height / 2
            linkActionLayer.frame = CGRect(x: linkActionLayerXPosition, y: linkActionLayerYPosition,
                                           width: linkActionLayerFrameSize.width, height: linkActionLayerFrameSize.height)
        }
    }

    override var mainLayerName: String {
        return "LinkSection"
    }
}
