//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    @State private var contentIsScrolled = false
    @State private var previousDragChangeTime: Date?

    private var isToolbarAboveContent: Bool {
        contentIsScrolled && [.note, .today].contains(state.mode)
    }

    var mainAppContent: some View {
        GeometryReader { geometry in
            ModeView(containerGeometry: geometry, contentIsScrolled: $contentIsScrolled)
                .frame(maxWidth: .infinity)
                .overlay(Toolbar(isAboveContent: isToolbarAboveContent), alignment: .top)
                .overlay(shouldDisplayBottomBar ?
                         WindowBottomToolBar()
                            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.2))) : nil, alignment: .bottom)
                .overlay(
                    OmniboxContainer(containerGeometry: geometry).environmentObject(state.autocompleteManager),
                    alignment: .top
                )
                .overlay(sidebar, alignment: .leading)
                .overlay(sidebarIcon, alignment: .topLeading)
        }
    }

    @ViewBuilder var sidebarIcon: some View {
        if state.useSidebar {
            ToolbarButton(icon: "nav-sidebar") {
                state.showSidebar.toggle()
            }
            .tooltipOnHover(state.showSidebar ? "Hide sidebar" : "Show sidebar")
            .padding(.leading, 10 + (state.isFullScreen ? 0 : BeamWindow.windowControlsWidth))
            .padding(.top, 12)
        }
    }

    @ViewBuilder var sidebar: some View {
        if state.useSidebar && state.showSidebar {
            SidebarView(pinnedManager: state.data.pinnedManager)
        }
    }

    @ViewBuilder var sideNote: some View {
        if let sideNote = state.sideNote {
            MiniEditor(note: sideNote)
        }
    }

    @ViewBuilder var sideNoteSeparator: some View {
        if state.sideNote != nil {
            Rectangle()
                .frame(width: BeamWindow.middleSeparatorWidth)
                .foregroundColor(.clear)
                .overlay(sideNoteSeparatorOverlay, alignment: .center)
        }
    }

    @ViewBuilder private var sideNoteSeparatorOverlay: some View {
        Rectangle()
            .foregroundColor(.clear)
            .ignoresSafeArea()
            .frame(width: 10)
            .cursorOverride(.resizeLeftRight)
            .background(ClickCatchingView(onRightTap: { event in
                presentSplitViewContextMenu(at: event.locationInWindow)
            }))
            .gesture(DragGesture().onChanged { value in
                // This is a basic throttling mecanism to prevent to many relayout during the resize.
                // Too many relayout seems to cause a loop inside AttributedGraph's code
                if let previousDragChangeTime = previousDragChangeTime,
                   value.time.timeIntervalSince(previousDragChangeTime) < 0.01 {
                    return
                }
                state.isResizingSplitView = true
                previousDragChangeTime = value.time
                let newWidth = state.sideNoteWidth - value.translation.width
                state.sideNoteWidth = newWidth.clamp(440, state.maxWidthForSplitView)
            }.onEnded({ _ in
                state.isResizingSplitView = false
            }))
    }

    //This disable the radius in split view for now, as they break the display of the NoteView after pivoting from the web
    let enableRadius = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                mainAppContent
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
                    .frame(minWidth: AppDelegate.defaultWindowMinimumSize.width)
                    .background(BeamColor.Generic.background.swiftUI)
                    .if(enableRadius, transform: { $0.cornerRadius(8) })
                    .edgesIgnoringSafeArea(.top)
                    .zIndex(0)
                    .animation(.easeInOut(duration:0.2), value: state.sideNote)
                sideNoteSeparator
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .animation(.easeInOut(duration: 0.2), value: state.sideNote)
                sideNote
                    .transition(sideNoteTransition)
                    .frame(width: state.sideNoteWidth)
                    .background(BeamColor.Generic.background.swiftUI)
                    .zIndex(0)
                    .if(enableRadius, transform: { $0.cornerRadius(8) })
                    .edgesIgnoringSafeArea(.top)
            }
            OverlayViewCenter(viewModel: state.overlayViewModel)
                .edgesIgnoringSafeArea(.top)
                .zIndex(1)
        }
        .environment(\.isMainWindow, windowInfo.windowIsMain)
        .environment(\.isCompactContentView, windowInfo.isCompactWidth)
        .environment(\.windowFrame, windowInfo.windowFrame)
        .faviconProvider(state.data.faviconProvider)
    }

    private var sideNoteTransition: AnyTransition {
        AnyTransition.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2).delay(0.1)),
                                 removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
    }

    private var shouldDisplayBottomBar: Bool {
        switch state.mode {
        case .web:
            return false
        case .page:
            guard let page = state.currentPage, page.id != WindowPage.shortcutsWindowPage.id else { return false }
            return true
        default:
            return true
        }
    }

    private func presentSplitViewContextMenu(at position: CGPoint) {
        let menu = NSMenu()

        let sizeControls = SplitViewSizeControlView(state: state) { [weak menu] in
            menu?.cancelTracking()
        }
        let menuSizeControl = ContentViewMenuItem(title: NSLocalizedString("Resize Split View", comment: ""),
                                                  contentView: { sizeControls })

        menu.addItem(menuSizeControl)
        menu.addItem(.fullWidthSeparator())
        menu.addItem(withTitle: NSLocalizedString("Detach Side Note", comment: "")) { item in
            guard let sideNote = state.sideNote else { return }
            state.openNoteInMiniEditor(id: sideNote.id)
            state.sideNote = nil
        }

        menu.addItem(withTitle: NSLocalizedString("Close Side Note", comment: "")) { item in
            state.sideNote = nil
        }

        menu.popUp(positioning: nil, at: position, in: windowInfo.window?.contentView)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
