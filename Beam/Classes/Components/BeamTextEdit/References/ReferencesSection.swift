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
            let o = open
            performLayerChanges {
                self.linkLayer?.layer.isHidden = !o
            }
        }
    }

    override func setupUI(openChildren: Bool) {
        super.setupUI(openChildren: openChildren)
        performLayerChanges {
            self.linkActionLayer.font = BeamFont.medium(size: 0).nsFont
            self.linkActionLayer.fontSize = 12
            self.linkActionLayer.contentsScale = self.contentsScale
            self.linkActionLayer.alignmentMode = .center
            self.linkActionLayer.string = "Link All"
        }
    }

    override var links: [BeamNoteReference] { note.fastReferences }
    override var sectionTypeName: StaticString { "ReferenceSection" }

    /// This overriden implementation of setupSectionMode does a late init.
    override func setupSectionMode() {
        self.createLinkAllLayer()
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self = self else { return }
            self.doSetupSectionMode()
        }

        note.$title
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateLinkedReferences(links: self.links)
            }.store(in: &scope)
    }

    override func updateInitialHeading() {
        updateHeading(note.fastReferences.count - note.links.count)
    }

    override func updateHeading(_ count: Int) {
        performLayerChanges {
            self.sectionTitleLayer.string = "reference".localizedStringWith(comment: "reference section title", count)
            self.selfVisible = count != 0
            self.visible = self.selfVisible
            self.sectionTitleLayer.isHidden = !self.selfVisible
            self.separatorLayer.isHidden = !self.selfVisible
        }
    }

    override func shouldHandleReference(rootNote: String, rootNoteId: UUID, text: BeamText, proxy: ProxyTextNode?) -> Bool {
        let linksToNote = text.hasLinkToNote(id: rootNoteId)
        let referencesToNote = text.hasReferenceToNote(titled: rootNote)

        let isChild = proxy?.allParents.contains(self) ?? false
        let isFocused = proxy?.isFocused ?? false
        let mayBeDanglingRef = isChild && isFocused
        let result = !linksToNote && (referencesToNote || mayBeDanglingRef)
        Logger.shared.logInfo("ReferenceSection.shouldHandleReference to \(rootNote) - \(rootNoteId): \(result) [!linksToNote.\(linksToNote) && (referencesToNote.\(referencesToNote) || Dangling.\(mayBeDanglingRef)] - text: \(text.text)", category: .noteEditor)
        return result
    }

    func createLinkAllLayer() {
        performLayerChanges {
            let linkContentLayer = CALayer()
            linkContentLayer.addSublayer(self.linkActionLayer)

            self.linkLayer = LinkButtonLayer(
                "linkAllLayer",
                linkContentLayer,
                activated: { [weak self] in
                    guard let self = self else { return }

                    if let linkLayer = self.linkLayer, linkLayer.layer.isHidden { return }

                    for child in self.children {
                        for crumb in child.children {
                            guard let breadCrumb = crumb as? BreadCrumb else { continue }
                            breadCrumb.convertReferenceToLink()
                        }
                    }
                }, hovered: {[weak self] isHover in
                    guard let self = self else { return }

                    self.linkActionLayer.foregroundColor = isHover ? BeamColor.LinkedSection.actionButtonHover.cgColor : BeamColor.LinkedSection.actionButton.cgColor
                })
        }
        guard let linkLayer = linkLayer else { return }
        linkLayer.setAccessibilityIdentifier("link-all-references-button")
        addLayer(linkLayer)
    }

    override func updateSubLayersLayout() {
        performLayerChanges(true) {
            self.setupLayerFrame()
            self.separatorLayer.frame = CGRect(x: 0, y: self.sectionTitleLayer.frame.maxY + 4, width: self.availableWidth, height: 1)

            guard let linkAllLayer = self.linkLayer else { return }
            linkAllLayer.layer.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
            let linkActionLayerFrameSize = self.linkActionLayer.preferredFrameSize()

            linkAllLayer.frame = CGRect(origin: CGPoint(x: self.availableWidth - linkActionLayerFrameSize.width - 10, y: -3), size: NSSize(width: 54, height: 21))

            let linkActionLayerXPosition = linkAllLayer.bounds.width / 2 - linkActionLayerFrameSize.width / 2
            let linkActionLayerYPosition = linkAllLayer.bounds.height / 2 - linkActionLayerFrameSize.height / 2
            self.linkActionLayer.frame = CGRect(x: linkActionLayerXPosition, y: linkActionLayerYPosition,
                                           width: linkActionLayerFrameSize.width, height: linkActionLayerFrameSize.height)
        }
    }

    override func updateColors() {
        super.updateColors()

        linkActionLayer.foregroundColor = BeamColor.LinkedSection.actionButton.cgColor
        linkActionLayer.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
    }

    override var mainLayerName: String {
        return "ReferencesSection"
    }
}
