//
//  HyperlinkFormatterView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 12/02/2021.
//

import Cocoa
import SwiftUI
import Combine

// MARK: - SwiftUI View
private class HyperlinkEditorViewModel: BaseFormatterViewViewModel, ObservableObject {
    override var animationDirection: Edge {
        get { .top }
        set { _ = newValue }
    }
    var url: Binding<String> = .constant("")
    var title: Binding<String> = .constant("")
    @Published var shouldFocusOnAppear: Bool = false
}

private struct HyperlinkEditorView: View {
    static let idealSize = CGSize(width: 240, height: sectionHeight * 2 + Separator.height)

    static var extraPadding: CGSize {
        CGSize(width: 40, height: 40)
    }

    private static let sectionHeight: CGFloat = 40
    private static let containerVerticalPadding = BeamSpacing._20

    @ObservedObject var viewModel: HyperlinkEditorViewModel = HyperlinkEditorViewModel()

    var onFinishEditing : ((_ canceled: Bool) -> Void)?
    var onCopy: (() -> Void)?

    @State private var isEditingTitle = false
    @State private var isEditingUrl = false

    @State private var isHoveringURLCopyIcon = false
    @State private var showOverlayForCopyIcon: Bool = false

    private var titleTextColor: NSColor {
        isEditingTitle ? BeamColor.Generic.text.nsColor : BeamColor.Generic.placeholder.nsColor
    }
    private var urlTextColor: NSColor {
        isEditingUrl ? BeamColor.Generic.text.nsColor : BeamColor.Generic.placeholder.nsColor
    }

    var body: some View {
        FormatterViewBackground(showBorder: true) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 4) {
                    textField(viewModel.title, editingBinding: $isEditingTitle, placeholder: "Title")
                    Icon(name: "shortcut-return", width: 12, color: BeamColor.LightStoneGray.swiftUI)
                        .opacity(isEditingTitle ? 1 : 0)
                        .padding(BeamSpacing._20)
                        .onTapGesture {
                            onFinishEditing?(false)
                        }
                }
                .frame(height: Self.sectionHeight)

                Separator(horizontal: true)

                HStack(alignment: .center, spacing: 4) {
                    textField(viewModel.url, editingBinding: $isEditingUrl, placeholder: "Link URL")
                    urlIcon
                        .padding(BeamSpacing._20)
                }
                .frame(height: Self.sectionHeight)
            }
            .animation(nil)
            .padding(.horizontal, BeamSpacing._100)
        }
        .frame(width: Self.idealSize.width, height: Self.idealSize.height)
        .overlay(!showOverlayForCopyIcon ? nil : Tooltip(title: "Link Copied")
            .fixedSize()
            .offset(x: Self.idealSize.width - BeamSpacing._100 + BeamSpacing._40, y: Self.sectionHeight / 2.0)
            .transition(Tooltip.defaultTransition), alignment: .leading)
        .formatterViewBackgroundAnimation(with: viewModel)
        .onReceive(Publishers.Zip(
            viewModel.$visible,
            viewModel.$shouldFocusOnAppear
        ), perform: { visible, shouldFocusOnAppear in
            if visible && shouldFocusOnAppear {
                DispatchQueue.main.async {
                    isEditingUrl = true
                }
            }
        })
    }

    private func textField(_ textBinding: Binding<String>, editingBinding: Binding<Bool>, placeholder: String) -> some View {
        return BeamTextField(text: textBinding,
                             isEditing: editingBinding,
                             placeholder: placeholder,
                             font: BeamFont.regular(size: 13).nsFont,
                             textColor: BeamColor.Generic.text.nsColor,
                             placeholderColor: BeamColor.Generic.placeholder.nsColor,
                             onCommit: { _ in
                                onFinishEditing?(false)
                             }, onEscape: {
                                onFinishEditing?(true)
                             })
            .frame(height: Self.sectionHeight)
    }

    private var urlIconCopyColor: Color {
        isHoveringURLCopyIcon ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI
    }

    @ViewBuilder
    private var urlIcon: some View {
        if isEditingUrl {
            Icon(name: "shortcut-return", width: 12, color: BeamColor.LightStoneGray.swiftUI)
                .onTapGesture {
                    onFinishEditing?(false)
                }
        } else {
            Icon(name: "editor-url_copy", width: 12, color: urlIconCopyColor)
                .onHover { isHoveringURLCopyIcon = $0 }
                .onTapGestureToggle($showOverlayForCopyIcon, scheduler: DispatchQueue.main, delay: 2.0) {
                    onCopy?()
                }
        }
    }
}

struct HyperlinkEditorView_Previews: PreviewProvider {

    static var previews: some View {
        let model = HyperlinkEditorViewModel()
        model.url = .constant("https://beamapp.co")
        model.title = .constant("Beam website")
        model.visible = true
        return HyperlinkEditorView(viewModel: model)
            .frame(width: 300, height: 90)
    }
}

// MARK: - NSView Container

protocol HyperlinkFormatterViewDelegate: AnyObject {
    func hyperlinkFormatterView(_ hyperlinkFormatterView: HyperlinkFormatterView,
                                didFinishEditing newUrl: String?,
                                newTitle: String?,
                                originalUrl: String?)
    func hyperlinkFormatterView(_ hyperlinkFormatterView: HyperlinkFormatterView, copyingURL: String)
}

class HyperlinkFormatterView: FormatterView {

    weak var delegate: HyperlinkFormatterViewDelegate?

    private var hostView: NSHostingView<HyperlinkEditorView>?
    private var originalUrlValue: String?
    private var originalTitleValue: String?
    private var subviewModel = HyperlinkEditorViewModel()

    override var idealSize: CGSize {
        HyperlinkEditorView.idealSize
    }

    override var extraPadding: CGSize {
        HyperlinkEditorView.extraPadding
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        super.animateOnAppear()
        subviewModel.visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.appearAnimationDuration) {
            completionHandler?()
        }
    }

    override func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        super.animateOnDisappear()
        subviewModel.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    // MARK: Private Methods
    private var editingUrl: String = "testing"
    private var editingTitle: String = "testing title"
    override func setupUI() {
        super.setupUI()

        subviewModel.url = Binding<String>(get: {
            self.editingUrl
        }, set: {
            self.editingUrl = $0
        })
        subviewModel.title = Binding<String>(get: {
            self.editingTitle
        }, set: {
            self.editingTitle = $0
        })
        let rootView = HyperlinkEditorView(viewModel: subviewModel) { [weak self] canceled in
            self?.sendFinishWithLinkEditing(canceled: canceled)
        } onCopy: { [weak self] in
            self?.sendCopyingURL()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds

        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    private func sendFinishWithLinkEditing(canceled: Bool) {
        let newUrl = !canceled && editingUrl != originalUrlValue ? editingUrl : nil
        let newTitle = !canceled && editingTitle != originalTitleValue ? editingTitle : nil
        delegate?.hyperlinkFormatterView(self, didFinishEditing: newUrl,
                                         newTitle: newTitle,
                                         originalUrl: originalUrlValue)
    }

    private func sendCopyingURL() {
        let url = originalUrlValue ?? editingUrl
        delegate?.hyperlinkFormatterView(self, copyingURL: url)
    }
}

// MARK: Public methods
extension HyperlinkFormatterView {

    func setInitialValues(url: String?, title: String?) {
        self.originalUrlValue = url
        self.originalTitleValue = title
        self.editingTitle = title ?? ""
        self.editingUrl = url ?? ""
    }

    func setEditedValues(url: String?, title: String?) {
        self.editingTitle = title ?? self.editingTitle
        self.editingUrl = url ?? self.editingUrl
    }

    func hasEditedUrl() -> Bool {
        return editingUrl != originalUrlValue || editingTitle != originalTitleValue
    }

    func startEditingUrl() {
        self.window?.makeKey()
        subviewModel.shouldFocusOnAppear = true
    }

}

// MARK: - Helpers

private extension View {

    func onTapGestureToggle<S: Scheduler>(
        _ binding: Binding<Bool>,
        scheduler: S,
        delay: S.SchedulerTimeType.Stride,
        completion: (() -> Void)? = nil
    ) -> some View {
        onTapGesture {
            binding.wrappedValue.toggle()
            scheduler.schedule(after: scheduler.now.advanced(by: delay)) {
                binding.wrappedValue.toggle()
            }
            completion?()
        }
    }

}
