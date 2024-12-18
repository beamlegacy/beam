//
//  GutterContainerView.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation
import SwiftUI

struct GutterView: View {
    var isLeading: Bool
    var leadingGutterViewType: LeadingGutterView.LeadingGutterViewType?
    weak var trailingGutterViewModel: TrailingGutterView.Model?

    var body: some View {
        if isLeading {
            if let leadingGutterViewType = leadingGutterViewType {
                LeadingGutterView(type: leadingGutterViewType)
            }
        } else {
            if let trailingGutterViewModel = trailingGutterViewModel {
                TrailingGutterView(model: trailingGutterViewModel)
            }
        }
    }
}

struct LeadingGutterView: View {
    enum LeadingGutterViewType {
        case calendarGutterView(viewModel: CalendarGutterViewModel)
    }
    var type: LeadingGutterViewType

    var body: some View {
        GeometryReader { geometry in
            VStack {
                switch type {
                case .calendarGutterView(let viewModel):
                    CalendarView(viewModel: viewModel)
                }
            }.frame(maxWidth: 221, maxHeight: .infinity, alignment: .topLeading)
                .frame(width: geometry.size.width, alignment: .topLeading)
                .zIndex(1000)
        }
    }
}

struct TrailingGutterView: View {
    @ObservedObject var model: Model

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                ForEach(model.items) { item in
                    GutterItemView(item: item, containerGeometry: geometry)
                }
            }
            .onHover {
                if $0 {
                    NSCursor.arrow.set()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .frame(width: geometry.size.width, alignment: .topTrailing)
            .zIndex(1000)
        }
    }
}

extension TrailingGutterView {
    class Model: ObservableObject {
        @Published var items: [GutterItem]
        init(items: [GutterItem]) {
            self.items = items
        }
    }
}

class GutterContainerView: NSView {
    override var isFlipped: Bool {
        true
    }

    var isLeading: Bool
    var leadingGutterViewType: LeadingGutterView.LeadingGutterViewType? {
        didSet {
            setupUI()
        }
    }
    private var trailingGutterViewModel = TrailingGutterView.Model(items: [])

    init(frame frameRect: NSRect, isLeading: Bool, leadingGutterViewType: LeadingGutterView.LeadingGutterViewType? = nil) {
        self.isLeading = isLeading
        self.leadingGutterViewType = leadingGutterViewType
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        self.subviews.removeAll()
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        let view = NSHostingView(rootView: GutterView(isLeading: isLeading,
                                                      leadingGutterViewType: leadingGutterViewType,
                                                      trailingGutterViewModel: trailingGutterViewModel))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.masksToBounds = false

        self.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        let trailing = view.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        trailing.priority = .defaultHigh

        let width = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            trailing,
            view.topAnchor.constraint(equalTo: self.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            width
        ])
        self.layer?.zPosition = 2.0
    }

    override var intrinsicContentSize: NSSize {
        switch leadingGutterViewType {
        case .calendarGutterView(let viewModel):
            let calendarCellHeight = Int(CalendarView.bottomPadding + CalendarItemView.itemSize.height)
            if viewModel.meetings.count > 0 {
                return NSSize(width: 0, height: (Int(CalendarView.itemSpacing) + calendarCellHeight) * (viewModel.meetings.count - 1) + calendarCellHeight)
            }
            let notConnectViewIsPresent = viewModel.todaysCalendar && viewModel.calendarManager.showedNotConnectedView < 3 && !viewModel.isConnected
            return NSSize(width: 0, height: notConnectViewIsPresent ? calendarCellHeight * 3 : 0)
        case .none:
            return .zero
        }
    }

    func addItem(_ item: GutterItem) {
        trailingGutterViewModel.items.append(item)
    }

    func removeItem(_ item: GutterItem) {
        trailingGutterViewModel.items.removeAll(where: { i in
            i == item
        })
    }
}
