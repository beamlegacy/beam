import AppKit
import Foundation
import Combine
import BeamCore

// swiftlint:disable file_length
class EmbedNode: ResizableNode {

    var isExpandable: Bool { true }

    override var frontmostHover: Bool {
        didSet {
            performLayerChanges {
                self.toggleButtonBeamLayer?.layer.opacity = self.frontmostHover ? 1 : 0
            }
        }
    }

    override var bulletLayerPositionY: CGFloat {
        if isCollapsed, let collapsedContentFirstBaseline = collapsedContent?.firstBaseline {
            return padding.top + collapsedContentFirstBaseline - 14
        } else {
            return expandedContentOrigin.y
        }
    }

    override var selectionLayerPosY: CGFloat {
        selectedAlone ? -5 : super.selectionLayerPosY
    }

    override var selectionLayerHeight: CGFloat {
        selectedAlone ? focusFrame.height + 1 : super.selectionLayerHeight
    }

    override var indentLayerPositionY: CGFloat { 28 }
    override var resizableContentBounds: CGRect { expandedContentFrame }

    private var expandedContent: EmbedContentView?
    private var collapsedContent: CollapsedContentLayer?
    private var toggleButtonBeamLayer: CollapseButtonLayer!
    private var focusBeamLayer: Layer!

    private let focusLayerBorderRadius: CGFloat = 3
    private let expandedContentSizeUpdateDebounceDelay = 1
    private let expandedContentAnimationKey = "expandedContent"
    private let collapseContentAnimationKey = "collapsedContent"

    /// Whether the element was initially sized from its last known display size retrieved from cache.
    private let didInitiallyUseCachedDisplaySize: Bool

    private var embedContent: EmbedContent? {
        didSet {
            guard let embedContent = embedContent else { return }
            contentGeometry.setGeometryDescription(.embed(embedContent))
        }
    }

    private var cancellables = Set<AnyCancellable>()

    /// A subject that broadcasts the size updates received from the embed content's script message handler.
    private lazy var expandedContentSizeSubject: PassthroughSubject<CGSize, Never> = {
        PassthroughSubject<CGSize, Never>()
    }()

    private var isCollapsed: Bool { isUserCollapsed || !isExpandable }

    private var isUserCollapsed = false {
        didSet {
            guard isUserCollapsed != oldValue else { return }
            applyCollapsedState(animated: true)
        }
    }

    private var visibleContentFrame: CGRect {
        isCollapsed ? collapsedContentFrame : expandedContentFrame
    }

    private var expandedContentFrame: CGRect {
        CGRect(origin: expandedContentOrigin, size: expandedContentSize)
    }

    private var expandedContentOrigin: CGPoint {
        CGPoint(x: contentsLead + 4, y: 0)
    }

    private var expandedContentFrameInEditorCoordinates: CGRect {
        layer.convert(expandedContentFrame, to: editor?.layer)
    }

    private var expandedContentSize: CGSize {
        contentGeometry.displaySize
    }

    private var collapsedContentOrigin: CGPoint {
        CGPoint(x: contentsLead + 4, y: contentsTop)
    }

    private var collapsedContentFrame: CGRect {
        CGRect(
            origin: collapsedContentOrigin,
            size: collapsedContent?.layer.frame.size ?? .zero
        )
    }

    private var toggleButtonOrigin: CGPoint {
        CGPoint(
            x: availableWidth + childInset + 11,
            y: contentsTop + 2
        )
    }

    private var focusFrame: CGRect {
        visibleContentFrame.insetBy(dx: -4, dy: -4)
    }

    private var focusColor: CGColor {
        isCollapsed ? BeamColor.Editor.linkActiveBackground.cgColor : selectionColor.cgColor
    }

    private var sourceURL: URL? {
        guard case let .embed(url, _, _) = element.kind else { return nil }
        return url
    }

    private var displayInfos: MediaDisplayInfos? {
        guard case let .embed(_, _, displayInfos) = element.kind else { return nil }
        return displayInfos
    }

    private var userSizedEmbedContent: Bool {
        displayInfos?.displayRatio != nil
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        isUserCollapsed = element.collapsed

        let displaySizeCache = ElementNodeDisplaySizeCache(elementID: element.id)
        didInitiallyUseCachedDisplaySize = displaySizeCache.containsCachedDisplaySize

        var contentGeometry = MediaContentGeometry(
            sizePreferencesStorage: element,
            sizePreferencesPersistenceStrategy: .displayHeight,
            displaySizeCache: displaySizeCache
        )

        /// Lock the display size on the cache value, until the embed content is loaded and ready to be displayed.
        contentGeometry.isLocked = true

        super.init(parent: parent, element: element, availableWidth: availableWidth, contentGeometry: contentGeometry)

        addFocusLayer()

        if isExpandable {
            addToggleButton()
        }

        observeExpandedContentSizeUpdates()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)

        element.changed.sink { [weak self] change in
            let updatedElement = change.0
            let contentGeometry = MediaContentGeometry(
                sizePreferencesStorage: updatedElement,
                sizePreferencesPersistenceStrategy: .displayHeight
            )
            self?.contentGeometry = contentGeometry

            if let embedContent = self?.embedContent {
                self?.contentGeometry.setGeometryDescription(.embed(embedContent))
            }

            if updatedElement.collapsed != self?.isCollapsed {
                self?.isUserCollapsed = updatedElement.collapsed
            }
        }.store(in: &scope)
    }

    override func updateRendering() -> CGFloat {
        updateFocus()

        return visibleContentFrame.height
    }

    override func updateLayout() {
        super.updateLayout()

        layoutExpandedContent()
        layoutCollapsedContent()
        layoutFocusLayer()
        layoutToggleButton()
    }

    override func updateColors() {
        super.updateColors()

        focusBeamLayer?.layer.backgroundColor = self.focusColor
    }

    override func setBottomPaddings(withDefault: CGFloat) {
        super.setBottomPaddings(withDefault: isCollapsed ? 10 : 14)
    }

    override func updateElementCursor() {
        let referenceFrame = focusBeamLayer.layer.frame
        let cursorX: CGFloat
        let cursorWidth: CGFloat = 2

        if caretIndex == 0 {
            // Caret is placed before the embed
            cursorX = 0
        } else {
            // Caret is placed after the embed
            cursorX = referenceFrame.width - cursorWidth
        }

        let cursorRect = CGRect(
            x: cursorX,
            y: referenceFrame.minY - padding.top,
            width: cursorWidth,
            height: referenceFrame.height
        )

        layoutCursor(cursorRect)
    }

    override func updateFocus() {
        layoutCollapsedContent()
        layoutFocusLayer()
    }

    override func onFocus() {
        updateFocus()
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func updateLayersVisibility() {
        super.updateLayersVisibility()

        performLayerChanges {
            self.expandedContent?.isHidden = self.layer.isHidden
        }
    }

    override func willBeRemovedFromNote() {
        super.willBeRemovedFromNote()

        stopNotePlaying()
    }

    override func didMoveToWindow(_ window: NSWindow?) {
        if window != nil, expandedContent == nil {
            applyCollapsedState(animated: false)
        } else if window == nil {
            expandedContent?.removeFromSuperview()
            expandedContent = nil
        }
    }

    deinit {
        expandedContent?.removeFromSuperview()
    }

    override func updateForMove(isDragging: Bool) {
        super.updateForMove(isDragging: isDragging)

        // Make sure to remove all existing animations or weird stuff will happen
        self.expandedContent?.layer?.removeAllAnimations()

        // Hide the collapse/expand button
        toggleButtonBeamLayer.layer.isHidden = isDragging

        // Move expandedContent on top of moving layer (at zPosition 100)
        expandedContent?.layer?.zPosition = isDragging ? 101 : 1

        // Change opacity of the embed content
        expandedContent?.layer?.opacity = isDragging ? moveOpacityFactor : 1

        // Make sure to reset the transform
        expandedContent?.layer?.setAffineTransform(CGAffineTransform.identity)

        // Make the initial zoom transform
        let scaleFactor = isDragging ? moveScaleFactor : 1.0
        let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        expandedContent?.layer?.setAffineTransform(transform)
    }

    override func translateForMove(_ offset: CGPoint) {
        super.translateForMove(offset)

        // Create the transform for the expandedContent and apply it without animations to avoid lag
        let scale = CGAffineTransform(scaleX: moveScaleFactor, y: moveScaleFactor)
        let translate = CGAffineTransform(translationX: offset.x, y: offset.y)
        let final = scale.concatenating(translate)
        CATransaction.disableAnimations {
            self.expandedContent?.layer?.setAffineTransform(final)
        }
    }
}

extension EmbedNode {

    private func applyCollapsedState(animated: Bool) {
        if isCollapsed {
            collapse(animated: animated)
        } else {
            expand(animated: animated)
        }

        invalidateLayout()
    }

    private func expand(animated: Bool) {
        element.collapsed = false
        canBeResized = true

        if expandedContent == nil {
            expandedContent = makeExpandedContent()
            layoutExpandedContent()
            // We need this embed node to be a child of the editor's layer tree before we can add the expanded content.
            // Therefore we don't add it until the next layout pass.
        }

        if animated {
            let presentationAnimation = EmbedAnimator.makeExpandedContentPresentationAnimation()
            presentationAnimation.delegate = AnimationHandler(
                layer: expandedContent?.layer,
                removeAllAnimationsWhenFinished: true
            )

            let dismissalAnimation = EmbedAnimator.makeCollapsedContentDismissalAnimation()
            dismissalAnimation.delegate = AnimationHandler(animationDidFinishHandler: { [weak self] in
                self?.removeCollapsedContentFromView()
            })

            performLayerChanges {
                self.expandedContent?.layer?.add(presentationAnimation, forKey: self.expandedContentAnimationKey)
                self.collapsedContent?.layer.add(dismissalAnimation, forKey: self.collapseContentAnimationKey)
            }

        } else {
            removeCollapsedContentFromView()
        }
    }

    private func collapse(animated: Bool) {
        element.collapsed = true
        canBeResized = false

        if collapsedContent == nil {
            collapsedContent = makeCollapsedContent()
            layoutCollapsedContent()
            addLayer(collapsedContent!)
        }

        if animated {
            let presentationAnimation = EmbedAnimator.makeCollapsedContentPresentationAnimation()
            presentationAnimation.delegate = AnimationHandler(
                layer: collapsedContent?.layer,
                removeAllAnimationsWhenFinished: true
            )

            let dismissalAnimation = EmbedAnimator.makeExpandedContentDismissalAnimation()
            dismissalAnimation.delegate = AnimationHandler(animationDidFinishHandler: { [weak self] in
                self?.removeExpandedContentFromView()
            })

            performLayerChanges {
                self.collapsedContent?.layer.add(presentationAnimation, forKey: self.collapseContentAnimationKey)
                self.expandedContent?.layer?.add(dismissalAnimation, forKey: self.expandedContentAnimationKey)
            }

        } else {
            removeExpandedContentFromView()
        }
    }

    private func makeExpandedContent() -> EmbedContentView? {
        guard let editor = editor, let url = sourceURL else { return nil }

        let webViewProvider = BeamWebViewProvider(editor: editor, elementId: elementId, url: url)

        let loadingView = EmbedLoadingView()
        let contentView = EmbedContentView(
            frame: .zero,
            webViewProvider: webViewProvider,
            loadingView: loadingView
        )
        contentView.layer?.anchorPoint = .zero
        contentView.delegate = self

        // Load embed HTML markup
        Self.fetchEmbedContent(url: url)
            .sink { [url] completion in
                if case .failure = completion {
                    loadingView.showError()
                    Logger.shared.logError("Embed Node couldn't load content for \(url.absoluteString)", category: .embed)
                }
            } receiveValue: { [weak self] embedContent in
                self?.embedContent = embedContent
                self?.saveElementTitleIfNeeded()
                contentView.startLoadingWebView(embedContent: embedContent)
            }
            .store(in: &cancellables)

        // Retrieve provider name in order to set the placeholder image
        Self.fetchProvider(for: url)
            .sink { completion in
                if case .failure = completion {
                    loadingView.showDefaultImage()
                }
            } receiveValue: { provider in
                loadingView.showImage(for: provider)
            }
            .store(in: &cancellables)

        return contentView
    }

    private func makeCollapsedContent() -> CollapsedContentLayer? {
        guard let url = sourceURL else { return nil }

        let text: String
        if !element.text.isEmpty {
            text = element.text.text
        } else {
            // Fallback for cases when no title was captured, for example when pasting an embed link in a note
            text = url.absoluteString
        }

        let layer = CollapsedContentLayer(name: "collapsed", text: text) { [weak editor, weak element] in
            editor?.state?.handleOpenUrl(url, note: element?.note, element: element)
        }

        FaviconProvider.shared.favicon(fromURL: url) { [weak layer] favicon in
            guard let image = favicon?.image else { return }
            layer?.setImage(image)
        }

        return layer
    }

    private func addFocusLayer() {
        let focusLayer = CAShapeLayer()
        focusLayer.zPosition = 0
        focusLayer.cornerRadius = focusLayerBorderRadius

        focusBeamLayer = Layer(name: "focus", layer: focusLayer)

        addLayer(focusBeamLayer!, origin: .zero)
    }

    private func addToggleButton() {
        toggleButtonBeamLayer = CollapseButtonLayer(name: "toggle", isCollapsed: isCollapsed) { [weak self] isCollapsed in
            self?.isUserCollapsed = isCollapsed
        }

        toggleButtonBeamLayer?.layer.opacity = 0
        toggleButtonBeamLayer?.collapseText = NSLocalizedString("to Link", comment: "Embed collapse button label")
        toggleButtonBeamLayer?.expandText = NSLocalizedString("to Embed", comment: "Embed expand button label")

        addLayer(toggleButtonBeamLayer!)
    }

    private func layoutExpandedContent() {
        guard !isCollapsed else { return }
        guard !isDraggedForMove && !isDraggedForMoveByParent else { return }

        performLayerChanges {
            let frame = self.expandedContentFrameInEditorCoordinates
            if !self.isResizing {
                // Prevent UI jerkiness by disabling layer animations while the node is being resized
                self.expandedContent?.layer?.frame = frame
            }
        }

        // `BeamTextEdit` delayed initialization runs layout from a `.userInteractive` background queue.
        DispatchQueue.main.async { [weak self] in
            // Wait until the first layout passed, after which we know for sure the node has been added to the editor's
            // layer tree, until we make the expanded content visible.
            // We need to wait until the node is added to the editor's layer tree, to get its origin in this coordinate
            // space, and then place the expanded content at the same position.

            guard let self = self else { return }
            self.addExpandedContentToViewIfNeeded()
            self.performLayerChanges {
                self.expandedContent?.frame = self.expandedContentFrameInEditorCoordinates
            }
        }

    }

    private func layoutCollapsedContent() {
        guard isCollapsed else { return }

        CATransaction.disableAnimations {
            collapsedContent?.isFocused = isFocused
            collapsedContent?.maxWidth = contentsWidth
            collapsedContent?.sizeToFit()
            collapsedContent?.layer.frame.origin = collapsedContentOrigin
        }
    }

    private func layoutFocusLayer() {
        CATransaction.disableAnimations {
            focusBeamLayer?.layer.frame = focusFrame
            focusBeamLayer?.layer.opacity = isFocused ? 1 : 0
            focusBeamLayer?.layer.backgroundColor = focusColor
        }
    }

    private func layoutToggleButton() {
        CATransaction.disableAnimations {
            toggleButtonBeamLayer?.layer.frame.origin = toggleButtonOrigin
        }
    }

    private func addExpandedContentToViewIfNeeded() {
        guard layer.frame.origin != .zero else {
            // Assume that for some reason the embed node CALayer has not been placed at its correct location within
            // the editor layer yet. Therefore, skip adding the embed node NSView to the editor view tree for now,
            // until we know for sure the correct origin of the embed node layer within the editor, which we need to
            // position the embed node NSView. Yes it's a hack.
            return
        }

        guard let expandedContent = expandedContent, expandedContent.superview == nil else { return }
        performLayerChanges {
            expandedContent.layer?.zPosition = 1
        }
        editor?.addSubview(expandedContent)
    }

    private func removeExpandedContentFromView() {
        performLayerChanges {
            self.expandedContent?.removeFromSuperview()
        }
        expandedContent = nil
    }

    private func removeCollapsedContentFromView() {
        if let layer = collapsedContent {
            removeLayer(layer)
        }
        collapsedContent = nil
    }

    private func stopNotePlaying() {
        guard
            let note = editor?.note as? BeamNote,
            let url = sourceURL
        else {
            return
        }
        editor?.state?.noteMediaPlayerManager.stopNotePlaying(note: note, elementId: elementId, url: url)
    }

    /// Observes the size updates from the embed content's script message handler.
    ///
    /// Size updates are debounced because while an embed is loading, multiple temporary size updates can be received
    /// in a short amount of time, resulting in unnecessary resizes and UI stuttering.
    private func observeExpandedContentSizeUpdates() {
        expandedContentSizeSubject
            .debounce(for: .seconds(expandedContentSizeUpdateDebounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] size in
                self?.updateExpandedContentSize(size)
            }
            .store(in: &cancellables)
    }

    private func updateExpandedContentSize(_ size: CGSize) {
        contentGeometry.isLocked = false
        contentGeometry.setDisplaySizeOverride(size)
    }

    private func saveElementTitleIfNeeded() {
        guard
            let embedContent = embedContent,
            element.text.text != embedContent.title
        else {
            return
        }

        element.text = BeamText(text: embedContent.title)
    }

    private static func fetchEmbedContent(url: URL) -> AnyPublisher<EmbedContent, EmbedContentError> {
        EmbedContentBuilder().embeddableContentFromAnyStrategy(for: url)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private static func fetchProvider(for url: URL) -> AnyPublisher<EmbedProvider, Error> {
        SupportedEmbedDomains.shared.provider(for: url)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

}

// MARK: - EmbedContentViewDelegate

extension EmbedNode: EmbedContentViewDelegate {

    func embedContentViewDidBecomeReady(_ embedContentView: EmbedContentView) {
        if let embedContent = embedContent, !embedContent.hasHTMLContent {
            // If the embed is not HTML based, we won't receive size updates from the script message handler. Therefore
            // we can start computing display size immediately.
            contentGeometry.isLocked = false
        }
    }

    func embedContentView(_ embedContentView: EmbedContentView, contentSizeDidChange size: CGSize) {
        if didInitiallyUseCachedDisplaySize, !isResizing {
            // If the embed is not loaded from the first time, it was initially displayed from the its last known
            // size retrived from cache. Therefore, to prevent unnecessary size updates and UI stuttering, we debounce
            // the size updates received from the script message handler, since it's very likely the final one will
            // actually be identical to the initial display size.
            expandedContentSizeSubject.send(size)
        } else {
            // If the embed is loaded for the first time, we apply immediately the size updates received from the
            // script message handler.
            updateExpandedContentSize(size)
        }
    }

    func embedContentView(_ embedContentView: EmbedContentView, didRequestNewTab url: URL) {
        guard
            let destinationNote = root?.editor?.note as? BeamNote,
            let rootElement = root?.element,
            let state = self.editor?.state
        else {
            return
        }

        // Create a new tab with the targetURL, the current note as destinationNote and the embedNode as rootElement
        _ = state.createTab(withURL: url, note: destinationNote, rootElement: rootElement)
    }

    func embedContentView(
        _ embedContentView: EmbedContentView,
        didUpdateMediaPlayerController mediaPlayerController: MediaPlayerController?
    ) {
        guard
            let note = root?.editor?.note as? BeamNote,
            let webView = embedContentView.webView,
            let noteMediaPlayerManager = editor?.state?.noteMediaPlayerManager,
            let url = sourceURL
        else {
            return
        }

        if mediaPlayerController?.isPlaying == true {
            noteMediaPlayerManager.addNotePlaying(note: note, elementId: elementId, webView: webView, url: url)
        } else {
            noteMediaPlayerManager.stopNotePlaying(note: note, elementId: elementId, url: url)
        }
    }

}
