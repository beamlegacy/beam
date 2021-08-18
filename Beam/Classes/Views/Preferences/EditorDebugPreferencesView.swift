//
//  EditorDebugPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 06/08/2021.
//

import Foundation
import SwiftUI
import Preferences

var EditorDebugPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .editorDebug, title: "Editor UI Debug", imageName: "preferences-developer") {
    EditorDebugPreferencesView()
        .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
}

struct EditorDebugPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    @State var editorIsCentered = PreferencesManager.editorIsCentered
    @State var editorHeaderTopPadding = PreferencesManager.editorHeaderTopPadding
    @State var editorLeadingPercentage = PreferencesManager.editorLeadingPercentage
    @State var editorJournalTopPadding = PreferencesManager.editorJournalTopPadding
    @State var editorCardTopPadding = PreferencesManager.editorCardTopPadding
    @State var editorMinWidth = PreferencesManager.editorMinWidth
    @State var editorMaxWidth = PreferencesManager.editorMaxWidth
    @State var editorParentSpacing = PreferencesManager.editorParentSpacing
    @State var editorChildSpacing = PreferencesManager.editorChildSpacing

    @State var editorFontSize = PreferencesManager.editorFontSize
    @State var editorFontSizeHeadingOne = PreferencesManager.editorFontSizeHeadingOne
    @State var editorFontSizeHeadingTwo = PreferencesManager.editorFontSizeHeadingTwo
    @State var editorLineHeight = PreferencesManager.editorLineHeight
    @State var editorLineHeightMultipleLine = PreferencesManager.editorLineHeightMultipleLine
    @State var editorLineHeightHeading = PreferencesManager.editorLineHeightHeading

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                Text("Restart Beam App to properly refresh the UI")
                    .font(BeamFont.regular(size: 14).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            }

            Preferences.Section(bottomDivider: true) {
                VStack(alignment: .center) {
                    Text("Appearance Editor:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.frame(width: 250, alignment: .trailing)
            } content: {
                EditorAppearance(editorIsCentered: $editorIsCentered, editorLeadingPercentage: $editorLeadingPercentage, editorHeaderTopPadding: $editorHeaderTopPadding, editorJournalTopPadding: $editorJournalTopPadding, editorCardTopPadding: $editorCardTopPadding, editorMinWidth: $editorMinWidth, editorMaxWidth: $editorMaxWidth, editorParentSpacing: $editorParentSpacing, editorChildSpacing: $editorChildSpacing, formatter: formatter())
            }
            Preferences.Section(bottomDivider: true) {
                VStack(alignment: .center) {
                    Text("Appearance Font in Editor:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.frame(width: 250, alignment: .trailing)
            } content: {
                FontEditorAppearance(editorFontSize: $editorFontSize, editorFontSizeHeadingOne: $editorFontSizeHeadingOne, editorFontSizeHeadingTwo: $editorFontSizeHeadingTwo, editorLineHeight: $editorLineHeight, editorLineHeightMultipleLine: $editorLineHeightMultipleLine, editorLineHeightHeading: $editorLineHeightHeading, formatter: formatter())
            }
            Preferences.Section {
                VStack(alignment: .center) {
                    Text("Reset:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.frame(width: 250, alignment: .trailing)
            } content: {
                VStack(alignment: .trailing) {
                    Button("Default settings") {
                        PreferencesManager.resetDefaultValuesForEditorDebug()

                        editorIsCentered = PreferencesManager.editorIsCentered
                        editorLeadingPercentage = PreferencesManager.editorLeadingPercentage
                        editorHeaderTopPadding = PreferencesManager.editorHeaderTopPadding
                        editorJournalTopPadding = PreferencesManager.editorJournalTopPadding
                        editorCardTopPadding = PreferencesManager.editorCardTopPadding
                        editorMinWidth = PreferencesManager.editorMinWidth
                        editorMaxWidth = PreferencesManager.editorMaxWidth
                        editorParentSpacing = PreferencesManager.editorParentSpacing
                        editorChildSpacing = PreferencesManager.editorChildSpacing

                        editorFontSize = PreferencesManager.editorFontSize
                        editorFontSizeHeadingOne = PreferencesManager.editorFontSizeHeadingOne
                        editorFontSizeHeadingTwo = PreferencesManager.editorFontSizeHeadingTwo
                        editorLineHeight = PreferencesManager.editorLineHeight
                        editorLineHeightMultipleLine = PreferencesManager.editorLineHeightMultipleLine
                        editorLineHeightHeading = PreferencesManager.editorLineHeightHeading
                    }
                }
            }

        }
    }

    private func formatter() -> NumberFormatter {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2
        return fmt
    }
}

struct TextEditorUIDebugPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        EditorDebugPreferencesView()
    }
}

struct EditorAppearance: View {
    @Binding var editorIsCentered: Bool
    @Binding var editorLeadingPercentage: CGFloat
    @Binding var editorHeaderTopPadding: CGFloat
    @Binding var editorJournalTopPadding: CGFloat
    @Binding var editorCardTopPadding: CGFloat
    @Binding var editorMinWidth: Int
    @Binding var editorMaxWidth: Int
    @Binding var editorParentSpacing: CGFloat
    @Binding var editorChildSpacing: CGFloat
    var formatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading) {
            Checkbox(checkState: editorIsCentered, text: "Center Text Editor", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 12).swiftUI) { activated in
                editorIsCentered = activated
                PreferencesManager.editorIsCentered = activated
            }
            HStack {
                Text("Leading percentage")
                TextField("", value: $editorLeadingPercentage, formatter: formatter) { _ in
                } onCommit: {
                    if editorLeadingPercentage >= 50 {
                        editorLeadingPercentage = 50
                    }
                    PreferencesManager.editorLeadingPercentage = editorLeadingPercentage
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Header Top Padding")
                TextField("", value: $editorHeaderTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorHeaderTopPadding = editorHeaderTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Journal Content Top Padding")
                TextField("", value: $editorJournalTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorJournalTopPadding = editorJournalTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Card Content Top Padding")
                TextField("", value: $editorCardTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorCardTopPadding = editorCardTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Editor Min Width")
                TextField("", value: $editorMinWidth, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorMinWidth = editorMinWidth
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Editor Max Width")
                TextField("", value: $editorMaxWidth, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorMaxWidth = editorMaxWidth
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Spacing between parent bullets")
                TextField("", value: $editorParentSpacing, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorParentSpacing = editorParentSpacing
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                Text("Spacing between child bullets")
                TextField("", value: $editorChildSpacing, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorChildSpacing = editorChildSpacing
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }
        }
    }
}

struct FontEditorAppearance: View {
    @Binding var editorFontSize: CGFloat
    @Binding var editorFontSizeHeadingOne: CGFloat
    @Binding var editorFontSizeHeadingTwo: CGFloat
    @Binding var editorLineHeight: CGFloat
    @Binding var editorLineHeightMultipleLine: CGFloat
    @Binding var editorLineHeightHeading: CGFloat

    var formatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Font Size")
                TextField("", value: $editorFontSize, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSize = editorFontSize
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25)
            }

            HStack {
                Text("Heading One Font Size")
                TextField("", value: $editorFontSizeHeadingOne, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSizeHeadingOne = editorFontSizeHeadingOne
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25)
            }

            HStack {
                Text("Heading Two Line Height")
                TextField("", value: $editorFontSizeHeadingTwo, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSizeHeadingTwo = editorFontSizeHeadingTwo
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25)
            }

            HStack {
                Text("Line Height for Multiple Lines")
                TextField("", value: $editorLineHeightMultipleLine, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorLineHeightMultipleLine = editorLineHeightMultipleLine
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25)
            }

            HStack {
                Text("Line Height for Headers")
                TextField("", value: $editorLineHeightHeading, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorLineHeightHeading = editorLineHeightHeading
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25)
            }
        }
    }
}
