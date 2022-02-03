import SwiftUI

struct OmniboxContentDebuggerView: View {
    @ObservedObject private var autocompleteManager = AutocompleteManager(with: AppDelegate.main.data, searchEngine: PreferredSearchEngine())
    private var textFieldText: Binding<String> {
        $autocompleteManager.searchQuery
    }
    private let textFont = BeamFont.regular(size: 15)
    private let backgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
    @State private var isEditing = false
    @State private var modifierFlagsPressed: NSEvent.ModifierFlags?
    @State private var selection: ResultSource? = .all

    let cornerSize = CGSize(width: 3, height: 3)

    enum ResultSource: String, Identifiable, CaseIterable {
        var id: Int {
            switch self {
            case .all:
                return 0
            case .sortedUrls:
                return 1
            }
        }

        case all
        case sortedUrls
    }

    var body: some View {
        VStack {
            BeamTextField(
                text: textFieldText,
                isEditing: $isEditing,
                placeholder: "Search Beam or the web",
                font: textFont.nsFont,
                textColor: BeamColor.Generic.text.nsColor,
                placeholderColor: BeamColor.Generic.placeholder.nsColor,
                selectedRange: autocompleteManager.searchQuerySelectedRange,
                selectedRangeColor: BeamColor.Generic.blueTextSelection.nsColor,
                multiline: true, // without this, the height is incorrect.
                textWillChange: {
                    autocompleteManager.replacementTextForProposedText($0)
                },
                onCommit: { modifierFlags in
                    onEnterPressed(modifierFlags: modifierFlags)
                },
                onEscape: onEscapePressed,
                onCursorMovement: { handleCursorMovement($0) },
                onModifierFlagPressed: { event in
                    modifierFlagsPressed = event.modifierFlags
                }
            ).frame(height: 40, alignment: .center)

            NavigationView {
                List(ResultSource.allCases, id: \.self, selection: $selection) { name in
                    NavigationLink(name.rawValue, destination: resultsView(selection: name), tag: name, selection: $selection)
                }
                .navigationTitle("List Selection")
                .toolbar {
                    Text("Edit?")
                }
            }
            .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, alignment: .topLeading)
        }
    }

    func resultsView(selection: ResultSource) -> some View {
        Group {
            switch selection {
            case .all:
                publisherResultsList(autocompleteManager.rawAutocompleteResults)
            case .sortedUrls:
                resultsList(autocompleteManager.rawSortedURLResults)
            }
        }
    }

    func publisherResultsList(_ results: [AutocompleteManager.AutocompletePublisherSourceResults]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(results) { source in
                    GroupBox(label:
                                Label("\(String(describing: source.source)) [\(source.results.count)]", image: source.source.iconName)
                    ) {
                        resultsList(source.results)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding([.leading, .trailing])
                }
            }
        }
    }

    func resultsList(_ results: [AutocompleteResult]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(results) { item in
                AutocompleteResultDebugView(item: item)
            }
        }

    }

    func onEnterPressed(modifierFlags: NSEvent.ModifierFlags?) {
//        let isCreateCardShortcut = modifierFlags?.contains(.option) == true
//        if isCreateCardShortcut {
//            if let createCardIndex = autocompleteManager.autocompleteResults.firstIndex(where: { (result) -> Bool in
//                return result.source == .createCard
//            }) {
//                autocompleteManager.autocompleteSelectedIndex = createCardIndex
//            }
//        }
//        startQuery()
    }

    func handleCursorMovement(_ move: CursorMovement) -> Bool {
        switch move {
        case .down, .up:
            NSCursor.setHiddenUntilMouseMoves(true)
            if move == .up {
                autocompleteManager.selectPreviousAutocomplete()
            } else {
                autocompleteManager.selectNextAutocomplete()
            }
            return true
        case .right, .left:
            return autocompleteManager.handleLeftRightCursorMovement(move)
        }
    }

    private func onEscapePressed() {
//        let query = autocompleteManager.searchQuery
//        if query.isEmpty || (state.mode == .web && query == state.browserTabsManager.currentTab?.url?.absoluteString) {
//            unfocusField()
//        } else {
//            autocompleteManager.setQuery("", updateAutocompleteResults: true)
//        }
    }

}

struct OmniboxContentDebuggerView_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxContentDebuggerView().background(Color.white)
    }
}
