//
//  ToolbarContentView.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct ToolbarContentView<List: DownloadListProtocol & PopoverWindowPresented>: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject private var downloadList: List
    @Environment(\.isMainWindow) private var isMainWindow: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var noteSwitcherFixedElementsWidth: CGFloat = 159.5

    private var showPivotButton: Bool {
        state.hasBrowserTabs
    }
    private var showDownloadsButton: Bool {
        let showButton = !downloadList.downloads.isEmpty
        if !showButton {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                downloadList.presentingWindow?.close()
            }
        }
        return showButton
    }

    init(downloadList: List) {
        self.downloadList = downloadList
    }

    // MARK: Views

    private var noteSwitcherViewModel: NoteSwitcherViewModel {
        if CardSwitcher.usePinnedInsteadOfRecentsNotes {
            return state.data.pinnedManager.viewModel
        } else {
            return state.recentsManager.viewModel
        }
    }

    private func cardSwitcherView(containerGeometry: GeometryProxy) -> some View {
        GlobalCenteringContainer(containerGeometry: containerGeometry) {
            if !state.useSidebar {
                CardSwitcher(currentNote: state.currentNote, viewModel: noteSwitcherViewModel)
                    .frame(maxHeight: .infinity)
                    .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
                    .environmentObject(state.recentsManager)
                    .onPreferenceChange(NoteSwitcherFixedElementsWidthPreferenceKey.self) { value in
                        noteSwitcherFixedElementsWidth = value ?? 0
                    }
            }
        }
        .transition(.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
            .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 8))
                .animation(BeamAnimation.spring(stiffness: 380, damping: 25))
            ),
                                removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
            .combined(with: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(BeamAnimation.spring(stiffness: 380, damping: 25).delay(0.03)))
        ))
        .modifier(ToolbarWidthMeasuring())
        .onPreferenceChange(ToolbarWidthPreferenceKey.self) { fullWidth in
            guard let fullWidth = fullWidth else { return }
            computeOverflowingNotesTitles(width: fullWidth)
        }
    }

    private func computeOverflowingNotesTitles(width: CGFloat) {
        let viewModel = noteSwitcherViewModel
        let numberOfSpacing = 5 // This is the number of spaces added by the main HStack of the CardSwitcher
        let spacings = Double(numberOfSpacing) * CardSwitcher.elementSpacing
        let overflowButtonWidth = 28.0
        var usableWidth = width - noteSwitcherFixedElementsWidth - spacings
        let font = BeamFont.regular(size: 11).nsFont
        var elementWidths = viewModel.elements.map { element in
            element.displayTitle.widthOfString(usingFont: font) + 17.0
        }
        let totalElementWidth = elementWidths.reduce(0, {$0 + $1})

        // If we have enough room for everyone, let's display everyone!
        guard totalElementWidth > usableWidth else {
            viewModel.dislayAllElements()
            return
        }

        // If we don't, let's remove items one by one to find the max we can display
        // But as we are going to display the overflow menu, don't forget to remove it from the available space
        usableWidth -= overflowButtonWidth
        var overflowCount = 1

        repeat {
            elementWidths.removeLast()
            overflowCount += 1
        } while elementWidths.reduce(0, {$0 + $1}) > usableWidth && overflowCount < viewModel.elements.count

        let numberOfElementsToHide = overflowCount - 1
        let startHidingIndex = viewModel.elements.count - numberOfElementsToHide
        for (offset, _) in viewModel.elements.enumerated() {
            var element = viewModel.elements[offset]
            element.isOverflowing = offset >= startHidingIndex
            viewModel.updateElement(element, at: offset)
        }
    }

    private func tabs(containerGeometry: GeometryProxy) -> some View {
        TabsListView(globalContainerGeometry: containerGeometry)
            .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
            .frame(maxHeight: .infinity)
            .transition(.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.12).delay(0.05))
                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: -8))
                                                    .animation(BeamAnimation.spring(stiffness: 380, damping: 25).delay(0.05))
                                                 ),
                                    removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 8))
                                                    .animation(BeamAnimation.spring(stiffness: 380, damping: 25))
                                                 )
                                   ))
    }

    private var leftFieldActions: some View {
        HStack(spacing: state.useSidebar ? 6 : 1) {
            if state.mode != .today && !state.useSidebar {
                ToolbarButton(icon: "nav-journal", action: goToJournal)
                    .tooltipOnHover(LocalizedStringKey(Shortcut.AvailableShortcut.showJournal.description))
                    .accessibilityIdentifier("journal")
                    .animation(nil)
            } else if state.useSidebar {
                Spacer().frame(width: 28, height: 28) // Spacer to ensure no overlap between sidebar buttons and chevrons
            }
            ToolbarChevrons()
                .animation(nil)
        }
    }

    private func rightActionsView(containerGeometry: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: BeamSpacing._100) {
            if showDownloadsButton {
                ToolbarDownloadButton(downloadList: downloadList, action: {
                    onDownloadButtonPressed(containerGeometry: containerGeometry)
                })
                    .background(GeometryReader { proxy -> Color in
                        let rect = proxy.safeTopLeftGlobalFrame(in: nil)
                        let center = CGPoint(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
                        state.downloadButtonPosition = center
                        return Color.clear
                    })
            }
            ToolbarButton(icon: "nav-omnibox", action: {
                if state.omniboxInfo.isFocused {
                    state.stopFocusOmnibox()
                } else {
                    state.startFocusOmnibox(fromTab: false)
                }
            })
                .tooltipOnHover(LocalizedStringKey(Shortcut.AvailableShortcut.newSearch.description))
                .accessibilityIdentifier("nav-omnibox")
            if showPivotButton {
                ToolbarModeSwitcher(isIncognito: state.isIncognito, modeWeb: state.mode != .web, tabsCount: state.browserTabsManager.tabs.count, action: toggleMode)
                    .tooltipOnHover(LocalizedStringKey(Shortcut.AvailableShortcut.toggleNoteWeb.description))
            }
        }
        .padding(.trailing, BeamSpacing._140)
    }

    var body: some View {
        GeometryReader { containerGeometry in
            HStack(alignment: .center, spacing: 0) {
                leftFieldActions
                if state.mode == .web {
                    tabs(containerGeometry: containerGeometry)
                        .padding(.horizontal, state.useSidebar ? BeamSpacing._140 : BeamSpacing._100)
                } else {
                    cardSwitcherView(containerGeometry: containerGeometry)
                        .padding(.horizontal, BeamSpacing._140)
                }
                rightActionsView(containerGeometry: containerGeometry)
            }
            .padding(.leading, (state.useSidebar ? 10 : 15) + (state.isFullScreen ? 0 : BeamWindow.windowControlsWidth))
            .frame(height: Toolbar.height, alignment: .top)
        }
        .frame(height: Toolbar.height, alignment: .top)
    }

    // MARK: Actions

    func goToJournal() {
        state.navigateToJournal(note: nil, clearNavigation: true)
    }

    func toggleSidebar() {
        state.showSidebar.toggle()
    }

    func toggleMode() {
        state.toggleBetweenWebAndNote()
    }

    private func onDownloadButtonPressed(containerGeometry: GeometryProxy) {
        if let downloaderWindow = downloadList.presentingWindow {
            CustomPopoverPresenter.shared.dismissPopoverWindow(downloaderWindow)
        } else if let window = CustomPopoverPresenter.shared.presentPopoverChildWindow(useBeamShadow: true, movable: false) {
            let downloaderView = DownloaderView(downloadList: downloadList) {
                CustomPopoverPresenter.shared.dismissPopovers(animated: false)
            }
            let toolbarFrame = containerGeometry.safeTopLeftGlobalFrame(in: window.parent)
            var origin = CGPoint(x: toolbarFrame.origin.x + toolbarFrame.width - downloaderView.preferredWidth - 18, y: toolbarFrame.maxY)
            if let parentWindow = window.parent {
                origin = origin.flippedPointToBottomLeftOrigin(in: parentWindow)
            }
            window.setView(with: downloaderView, at: origin, fromTopLeft: true)
            window.makeKey()
            downloadList.presentingWindow = window
        }
    }
}

struct ToolbarWidthPreferenceKey: FloatPreferenceKey { }

struct ToolbarWidthMeasuring: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
            GeometryReader { proxy in
                Color.clear.preference(key: ToolbarWidthPreferenceKey.self, value: proxy.size.width)
            }, alignment: .center)
    }
}

struct ToolbarContentView_Previews: PreviewProvider {
    static let state = BeamState()
    static let focusedState = BeamState()
    static let beamData = BeamData()
    static let browserTabManager = BrowserTabsManager(with: beamData, state: state)

    static var previews: some View {
        let emptyDownloadList = DownloadListFake(isDownloading: false)

        let runningDownloadList = DownloadListFake(
            isDownloading: true,
            progressFractionCompleted: 0.5
        )

        runningDownloadList.downloads = [
            DownloadListItemFake(
                filename: "Uno.txt",
                fileExtension: "txt"
            )
        ]

        state.stopFocusOmnibox()
        focusedState.startFocusOmnibox()
        focusedState.mode = .web
        let origin = BrowsingTreeOrigin.searchBar(query: "query", referringRootId: nil)
        if let note = try? BeamNote(title: "Note title") {
            focusedState.browserTabsManager.setCurrentTab(BrowserTab(state: focusedState, browsingTreeOrigin: origin, originMode: .today, note: note))

        }
        return Group {
            ToolbarContentView(downloadList: emptyDownloadList)
                .environmentObject(state)
                .environmentObject(browserTabManager)
            ToolbarContentView(downloadList: runningDownloadList)
                .environmentObject(state)
                .environmentObject(browserTabManager)
            ToolbarContentView(downloadList: emptyDownloadList)
                .environmentObject(focusedState)
                .environmentObject(browserTabManager)
            ToolbarContentView(downloadList: runningDownloadList)
                .environmentObject(focusedState)
                .environmentObject(browserTabManager)
        }.previewLayout(.fixed(width: 500, height: 60))
    }
}
