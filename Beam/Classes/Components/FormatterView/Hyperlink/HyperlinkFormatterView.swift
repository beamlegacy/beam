//
//  HyperlinkFormatterView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 12/02/2021.
//

import Cocoa
import SwiftUI

// MARK: - SwiftUI View
private class HyperlinkEditorViewModel: FormatterViewViewModel {
    var url: Binding<String> = .constant("")
    var title: Binding<String> = .constant("")
    @Published var shouldFocusOnAppear: Bool = false
}

private struct HyperlinkEditorView: View {
    @ObservedObject var viewModel: HyperlinkEditorViewModel = HyperlinkEditorViewModel()

    var onFinishEditing : ((_ canceled: Bool) -> Void)?

    @State private var isEditingUrl = false
    @State private var isEditingTitle = false

    private var titleTextColor: NSColor {
        return isEditingTitle ? .hyperlinkTextFielColor : .hyperlinkTextFielPlaceholderColor
    }
    private var urlTextColor: NSColor {
        return isEditingUrl ? .hyperlinkTextFielColor : .hyperlinkTextFielPlaceholderColor
    }

    func textField(_ textBinding: Binding<String>, editingBinding: Binding<Bool>, placeholder: String) -> some View {
        return BeamTextField(text: textBinding, isEditing: editingBinding, placeholder: placeholder, font: NSFont(name: "Inter-Medium", size: 10), textColor: editingBinding.wrappedValue ? .hyperlinkTextFielColor : .hyperlinkTextFielPlaceholderColor, placeholderColor: .hyperlinkTextFielPlaceholderColor, onCommit: { _ in
            onFinishEditing?(false)
        }, onEscape: {
            onFinishEditing?(true)
        })
    }

    var body: some View {
        FormatterViewBackground {
            VStack {
                HStack(spacing: 4) {
                    Icon(name: "editor-url_title", size: 16, color: Color(titleTextColor))
                    textField(viewModel.title, editingBinding: $isEditingTitle, placeholder: "Title")
                    if isEditingTitle {
                        Icon(name: "editor-format_enter", size: 12, color: Color(.hyperlinkTextFielPlaceholderColor))
                            .onTapGesture {
                                onFinishEditing?(false)
                            }
                    }
                }
                Separator(horizontal: true)
                    .padding(.horizontal, 2)
                HStack(spacing: 4) {
                    Icon(name: "editor-url_link", size: 16, color: Color(urlTextColor))
                    textField(viewModel.url, editingBinding: $isEditingUrl, placeholder: "URL")
                    if isEditingUrl {
                        Icon(name: "editor-format_enter", size: 12, color: Color(.hyperlinkTextFielPlaceholderColor))
                            .onTapGesture {
                                onFinishEditing?(false)
                            }
                    }
                }
            }
            .animation(nil)
            .padding(8)
        }
        .frame(width: 272, height: 65)
        .scaleEffect(viewModel.visible ? 1.0 : 0.98)
        .offset(x: 0, y: viewModel.visible ? 0.0 : 4.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(viewModel.visible ? 1.0 : 0.0)
        .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
        .onAppear {
            if viewModel.visible && viewModel.shouldFocusOnAppear {
                isEditingUrl = true
            }
        }
    }
}

private struct HyperlinkEditorView_Previews: PreviewProvider {

    static var previews: some View {
        let model = HyperlinkEditorViewModel()
        model.url = .constant("https://beamapp.co")
        model.title = .constant("Beam website")
        return HyperlinkEditorView(viewModel: model)
            .frame(width: 300, height: 90)
    }
}

// MARK: - NSView Container

protocol HyperlinkFormatterViewDelegate: class {
    func hyperlinkFormatterView(_ hyperlinkFormatterView: HyperlinkFormatterView, didFinishEditing newUrl: String?, newTitle: String?, originalUrl: String?)
}

class HyperlinkFormatterView: FormatterView {

    weak var delegate: HyperlinkFormatterViewDelegate?

    private var hostView: NSHostingView<HyperlinkEditorView>?
    private var originalUrlValue: String?
    private var originalTitleValue: String?
    private var subviewModel = HyperlinkEditorViewModel()

    override var idealSize: NSSize {
        return NSSize(width: 272, height: 65)
    }

    convenience init(viewType: FormatterViewType) {
        self.init(frame: CGRect.zero)
        self.viewType = viewType
        setupUI()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
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
    private func setupUI() {
        setupLayer()

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
        let rootView = HyperlinkEditorView(viewModel: subviewModel) { canceled in
            self.sendFinishWithLinkEditing(canceled: canceled)
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
        delegate?.hyperlinkFormatterView(self, didFinishEditing: newUrl, newTitle: newTitle, originalUrl: originalUrlValue)
    }
}

// MARK: Public methods
extension HyperlinkFormatterView {

    func updateHyperlinkFormatterView(withUrl url: String?, title: String?) {
        self.originalUrlValue = url
        self.originalTitleValue = title
        self.editingTitle = title ?? ""
        self.editingUrl = url ?? ""
    }

    func hasEditedUrl() -> Bool {
        return editingUrl != originalUrlValue || editingTitle != originalTitleValue
    }

    func startEditingUrl() {
        subviewModel.shouldFocusOnAppear = true
    }

}
