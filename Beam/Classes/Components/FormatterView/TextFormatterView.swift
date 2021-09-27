//
//  TextFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 13/04/2021.
//

import Foundation
import SwiftUI

// MARK: - SwiftUI View
private struct FormatterItem: Identifiable {
    let id: String
    let type: TextFormatterType
    let isActive: Bool
    init(type: TextFormatterType, isActive: Bool = false) {
        self.id = "\(type)-\(isActive ? 1 : 0)"
        self.type = type
        self.isActive = isActive
    }
}

private class TextFormatterViewModel: BaseFormatterViewViewModel, ObservableObject {
    override var animationDirection: Edge {
        get { .top }
        set { _ = newValue }
    }
    @Published var formatterItems: [FormatterItem] = []
    var onSelectFormatterItem: ((FormatterItem) -> Void)?
}

private struct TextFormatterViewSwiftUI: View {
    @ObservedObject var viewModel: TextFormatterViewModel
    @Environment(\.colorScheme) var colorScheme
    var alwaysShowShadow = true
    @State private var isHovering = false

    static func idealSize(forNumberOfItems: Int) -> CGSize {
        let itemSize = CGFloat(forNumberOfItems)
        let width = (itemSize * 38) + (BeamSpacing._40 * 2)
        return NSSize(width: width, height: 32)
    }

    private let buttonStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle()
        style.iconSize = 20
        style.foregroundColor = BeamColor.Corduroy.swiftUI
        return style
    }()

    var body: some View {
        let size = Self.idealSize(forNumberOfItems: viewModel.formatterItems.count)
        FormatterViewBackground(shadowOpacity: colorScheme == .dark ? 1 : 0.5) {
            HStack {
                ForEach(viewModel.formatterItems) { item in
                    ButtonLabel(icon: item.type.icon,
                                state: item.isActive ? .active : .normal,
                                customStyle: buttonStyle) {
                        viewModel.onSelectFormatterItem?(item)
                    }
                }
            }
            .animation(nil)
            .padding(BeamSpacing._40)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(width: size.width, height: size.height)
        .formatterViewBackgroundAnimation(with: viewModel)
    }
}

struct TextFormatterView_Previews: PreviewProvider {

    static var previews: some View {
        let model = TextFormatterViewModel()
        model.formatterItems = [.h1, .h2, .bold, .strikethrough].map { FormatterItem(type: $0, isActive: false ) }
        model.visible = true
        return TextFormatterViewSwiftUI(viewModel: model)
            .frame(width: 300, height: 90)
    }
}

// MARK: - NSView Container
protocol TextFormatterViewDelegate: AnyObject {
    func textFormatterView(_ textFormatterView: TextFormatterView,
                           didSelectFormatterType type: TextFormatterType,
                           isActive: Bool)
}

class TextFormatterView: FormatterView {

    weak var delegate: TextFormatterViewDelegate?
    var items: [TextFormatterType] = [] {
        didSet { updateFormatterItems() }
    }

    private var hostView: NSHostingView<TextFormatterViewSwiftUI>?
    private var subviewModel = TextFormatterViewModel()
    private var selectedTypes: Set<TextFormatterType> = []

    override var idealSize: CGSize {
        return TextFormatterViewSwiftUI.idealSize(forNumberOfItems: items.count)
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

    override func setupUI() {
        super.setupUI()
        subviewModel.onSelectFormatterItem = self.onSelectFormatterItem
        let rootView = TextFormatterViewSwiftUI(viewModel: subviewModel, alwaysShowShadow: self.viewType == .inline)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    // MARK: Private Methods
    private func onSelectFormatterItem(_ formatterItem: FormatterItem) {
        let type = formatterItem.type
        let isActive = selectedTypes.contains(type)

        if !selectedTypes.contains(type) { selectedTypes.insert(type) }

        removeState(type)

        if isActive {
            selectedTypes.remove(type)
        }
        updateFormatterItems()
        delegate?.textFormatterView(self, didSelectFormatterType: type, isActive: isActive)
    }

    private func updateFormatterItems() {
        let newItems = items.map {
            FormatterItem(type: $0, isActive: selectedTypes.contains($0))
        }
        subviewModel.formatterItems = newItems
    }

    private func removeState(_ type: TextFormatterType) {
        if type == .h2 && selectedTypes.contains(.h1) ||
           type == .quote && selectedTypes.contains(.h1) ||
           type == .code && selectedTypes.contains(.h1) { removeActiveIndicator(to: .h1) }

        if type == .h1 && selectedTypes.contains(.h2) ||
           type == .quote && selectedTypes.contains(.h2) ||
           type == .code && selectedTypes.contains(.h2) { removeActiveIndicator(to: .h2) }

        if type == .h2 && selectedTypes.contains(.quote) ||
           type == .h1 && selectedTypes.contains(.quote) { removeActiveIndicator(to: .quote) }

        if type == .h2 && selectedTypes.contains(.code) ||
           type == .h1 && selectedTypes.contains(.code) { removeActiveIndicator(to: .code) }
    }

    private func removeActiveIndicator(to item: TextFormatterType) {
        selectedTypes.remove(item)
    }

}

// MARK: Public methods
extension TextFormatterView {
    func setActiveFormatters(_ types: [TextFormatterType]) {
        selectedTypes = []
        types.forEach { type in
            selectedTypes.insert(type)
        }
        updateFormatterItems()
    }

    func setActiveFormatter(_ type: TextFormatterType) {
        removeState(type)
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        updateFormatterItems()
    }

    func resetSelectedItems() {
        self.selectedTypes = []
        updateFormatterItems()
    }
}
