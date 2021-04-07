//
//  ContextMenuFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

// MARK: - SwiftUI View

struct ContextMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: (() -> Void)?
}

private struct ContextMenuItemView: View {

    var item: ContextMenuItem

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(BeamColor.ContextMenu.hover.swiftUI.opacity(isHovering ? 1.0 : 0.0))
            Text(item.title)
                .font(BeamFont.medium(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.vertical, BeamSpacing._40)
                .padding(.horizontal, BeamSpacing._50)
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            isHovering = hovering
        }
    }

}

private struct ContextMenuView: View {

    @ObservedObject var viewModel = FormatterViewViewModel()
    static let itemHeight: CGFloat = 23
    static let defaultWidth: CGFloat = 160

    static func idealSizeForItems(_ items: [[ContextMenuItem]]) -> CGSize {
        let numberOfSections = items.count
        let numberOfItems = items.reduce(0) { (result, section) -> Int in
            return result + section.count
        }
        let spacing: CGFloat = 5.0
        let itemsHeights = CGFloat(numberOfItems) * (ContextMenuView.itemHeight + spacing)
        let height: CGFloat = spacing + itemsHeights + CGFloat(numberOfSections - 1) * (Separator.height + spacing)
        return CGSize(width: self.defaultWidth, height: height)
    }

    @Binding var items: [[ContextMenuItem]]

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<items.count) { i in
                    ForEach(items[i]) { item in
                        ContextMenuItemView(item: item)
                            .onTapGesture {
                                item.action?()
                            }
                    }
                    if i != items.count - 1 {
                        Separator(horizontal: true)
                    }
                }
            }
            .padding(BeamSpacing._50)
        }
        .zIndex(1000)
        .frame(minWidth: Self.defaultWidth)
        .scaleEffect(viewModel.visible ? 1.0 : 0.98)
        .offset(x: 0, y: viewModel.visible ? 0.0 : -4.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(viewModel.visible ? 1.0 : 0.0)
        .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
    }
}

struct ContextMenuView_Previews: PreviewProvider {

    private static var items = [
        [ContextMenuItem(title: "Open Link", action: nil)],
        [
            ContextMenuItem(title: "Copy Link", action: nil),
            ContextMenuItem(title: "Edit Link...", action: nil),
            ContextMenuItem(title: "Remove Link", action: nil)
        ]
    ]
    static var previews: some View {
        return ContextMenuView(items: .constant(Self.items))
            .padding(.all)
    }
}

// MARK: - NSView Container

class ContextMenuFormatterView: FormatterView {

    private var hostView: NSHostingView<ContextMenuView>?
    private var items: [[ContextMenuItem]] = []
    private var subviewModel = FormatterViewViewModel()

    override var idealSize: NSSize {
        return ContextMenuView.idealSizeForItems(items)
    }

    convenience init(viewType: FormatterViewType, items: [[ContextMenuItem]]) {
        self.init(frame: CGRect.zero)
        self.viewType = viewType
        self.items = items
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

    private func setupUI() {
        setupLayer()

        let rootView = ContextMenuView(viewModel: subviewModel, items: .constant(self.items))
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

}
