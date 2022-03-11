import AppKit
import Foundation
import Combine
import BeamCore

// swiftlint:disable file_length
class EmbedNode: ResizableNode {

    var isExpandable: Bool { true }

    override var hover: Bool {
        didSet {
            toggleButtonBeamLayer?.layer.opacity = hover ? 1 : 0
        }
    }

    override var bulletLayerPositionY: CGFloat {
        if isCollapsed, let collapsedContentFirstBaseline = collapsedContent?.firstBaseline {
            return padding.top + collapsedContentFirstBaseline - 14
        } else {
            return expandedContentOrigin.y
        }
    }

    override var indentLayerPositionY: CGFloat { 28 }
    override var resizableContentBounds: CGRect { expandedContentFrame }

    private var expandedContent: EmbedContentView?
    private var collapsedContent: CollapsedContentLayer?
    private var toggleButtonBeamLayer: CollapseButtonLayer!
    private var focusBeamLayer: Layer!

    static let initialExpandedContentSize = CGSize(width: 170, height: 128)
    private let focusLayerBorderRadius: CGFloat = 3
    private let expandedContentSizeUpdateDebounceDelay = 0.5
    private let expandedContentAnimationKey = "expandedContent"
    private let collapseContentAnimationKey = "collapsedContent"

    private var embedContent: EmbedContent? {
        didSet {
            minWidth = embedContent?.minWidth ?? minWidth
            minHeight = embedContent?.minHeight ?? minHeight
            maxWidth = embedContent?.maxWidth ?? maxWidth
            maxHeight = embedContent?.maxHeight ?? maxHeight
            keepAspectRatio = embedContent?.keepAspectRatio ?? keepAspectRatio
            responsiveStrategy = embedContent?.responsive ?? responsiveStrategy

            let width = embedContent?.width ?? resizableElementContentSize.width
            let height: CGFloat

            if let embedHeight = embedContent?.height {
                height = embedHeight
            } else {
                // If the embed doesn't have a default height, we compute it by applying the same initial aspect ratio
                // from the loading state onto the width
                height = width * Self.initialExpandedContentSize.aspectRatio
            }

            resizableElementContentSize = CGSize(width: width, height: height)
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
        if visibleSize != .zero {
            return visibleSize

        } else if let widthRatio = displayInfos?.displayRatio, let height = displayInfos?.height {
            // Restore size previously set by user and stored in element
            let width = Int(contentsWidth * widthRatio)
            return CGSize(width: width, height: height)

        } else {
            // Embed is displayed for the first time
            return Self.initialExpandedContentSize
        }
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
        super.init(parent: parent, element: element, availableWidth: availableWidth)

        isUserCollapsed = element.collapsed

        addFocusLayer()

        if isExpandable {
            addToggleButton()
        }

        observeExpandedContentSizeUpdates()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)
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

        focusBeamLayer?.layer.backgroundColor = focusColor
    }

    override func setBottomPaddings(withDefault: CGFloat) {
        super.setBottomPaddings(withDefault: isCollapsed ? 6 : 14)
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

        expandedContent?.isHidden = layer.isHidden
    }

    override func willBeRemovedFromNote() {
        super.willBeRemovedFromNote()

        stopNotePlaying()
    }

    deinit {
        expandedContent?.removeFromSuperview()
    }

    override func didMoveToWindow(_ window: NSWindow?) {
        if window != nil, expandedContent == nil {
            applyCollapsedState(animated: false)
        } else if window == nil {
            expandedContent?.removeFromSuperview()
            expandedContent = nil
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

            expandedContent?.layer?.add(presentationAnimation, forKey: expandedContentAnimationKey)
            collapsedContent?.layer.add(dismissalAnimation, forKey: collapseContentAnimationKey)

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

            collapsedContent?.layer.add(presentationAnimation, forKey: collapseContentAnimationKey)
            expandedContent?.layer?.add(dismissalAnimation, forKey: expandedContentAnimationKey)

        } else {
            removeExpandedContentFromView()
        }
    }

    private func makeExpandedContent() -> EmbedContentView? {
        guard let editor = editor, let url = sourceURL else { return nil }

        let webViewProvider = BeamWebViewProvider(editor: editor, elementId: elementId, url: url)

        let view = EmbedContentView(frame: .zero, webViewProvider: webViewProvider)
        view.layer?.anchorPoint = .zero
        view.delegate = self

        Self.fetchEmbedContent(url: url)
            .sink { [url] completion in
                if case .failure = completion {
                    Logger.shared.logError("Embed Node couldn't load content for \(url.absoluteString)", category: .embed)
                }
            } receiveValue: { [weak self] embedContent in
                self?.embedContent = embedContent
                self?.saveElementTitleIfNeeded()
                view.startLoadingWebView(embedContent: embedContent)
            }
            .store(in: &cancellables)

        return view
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

        let frame = expandedContentFrameInEditorCoordinates

        if !isResizing {
            // Prevent UI jerkiness by disabling layer animations while the node is being resized
            expandedContent?.layer?.frame = frame
        }

        // `BeamTextEdit` delayed initialization runs layout from a `.userInteractive` background queue.
        DispatchQueue.main.async { [weak expandedContent, weak self] in
            // Wait until the first layout passed, after which we know for sure the node has been added to the editor's
            // layer tree, until we make the expanded content visible.
            // We need to wait until the node is added to the editor's layer tree, to get its origin in this coordinate
            // space, and then place the expanded content at the same position.
            self?.addExpandedContentToViewIfNeeded()

            expandedContent?.frame = frame
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
        }
    }

    private func layoutToggleButton() {
        CATransaction.disableAnimations {
            toggleButtonBeamLayer?.layer.frame.origin = toggleButtonOrigin
        }
    }

    private func addExpandedContentToViewIfNeeded() {
        guard let expandedContent = expandedContent, expandedContent.superview == nil else { return }
        expandedContent.layer?.zPosition = 1
        editor?.addSubview(expandedContent)
    }

    private func removeExpandedContentFromView() {
        expandedContent?.removeFromSuperview()
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
    /// Size updates are debounced for the following reasons:
    /// - While an embed is loading, multiple temporary size updates can be received in a short amount of time,
    /// resulting in unnecessary resizes and UI stuttering.
    /// - When an embed is first displayed, we want to give it its previously known size first, and protect it from the
    /// temporary size updates happening during loading.
    private func observeExpandedContentSizeUpdates() {
        expandedContentSizeSubject
            .debounce(for: .seconds(expandedContentSizeUpdateDebounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] size in
                self?.updateExpandedContentSize(size)
            }
            .store(in: &cancellables)
    }

    private func updateExpandedContentSize(_ size: CGSize) {
        if embedContent?.height == nil {
            setVisibleHeight(size.height)
        }

        if embedContent?.width == nil {
            setVisibleWidth(size.width)
        }

        invalidateLayout()
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

}

// MARK: - EmbedContentViewDelegate

extension EmbedNode: EmbedContentViewDelegate {

    func embedContentView(_ embedContentView: EmbedContentView, contentSizeDidChange size: CGSize) {
        if isResizing {
            // Apply the new size immediately if the node is being resized, or if we don't have any preferred height yet
            updateExpandedContentSize(size)
        } else {
            // Wait until the embed content size stabilizes itself
            expandedContentSizeSubject.send(size)
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
