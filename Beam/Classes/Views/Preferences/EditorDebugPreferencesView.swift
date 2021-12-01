//
//  EditorDebugPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 06/08/2021.
//
//swiftlint:disable file_length

import Foundation
import SwiftUI
import Preferences

var EditorDebugPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .editorDebug, title: "Editor UI Debug", imageName: "preferences-editor-debug") {
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
    @State var editorToolbarOverlayOpacity = PreferencesManager.editorToolbarOverlayOpacity

    @State var editorFontSize = PreferencesManager.editorFontSize
    @State var editorCardTitleFontSize = PreferencesManager.editorCardTitleFontSize
    @State var editorFontSizeHeadingOne = PreferencesManager.editorFontSizeHeadingOne
    @State var editorFontSizeHeadingTwo = PreferencesManager.editorFontSizeHeadingTwo
    @State var editorHeaderOneSize = PreferencesManager.editorHeaderOneSize
    @State var editorHeaderTwoSize = PreferencesManager.editorHeaderTwoSize
    @State var editorLineHeight = PreferencesManager.editorLineHeight
    @State var editorLineHeightMultipleLine = PreferencesManager.editorLineHeightMultipleLine
    @State var editorLineHeightHeading = PreferencesManager.editorLineHeightHeading

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
                    EditorAppearance(editorIsCentered: $editorIsCentered,
                                     editorLeadingPercentage: $editorLeadingPercentage,
                                     editorHeaderTopPadding: $editorHeaderTopPadding,
                                     editorJournalTopPadding: $editorJournalTopPadding,
                                     editorCardTopPadding: $editorCardTopPadding,
                                     editorMinWidth: $editorMinWidth,
                                     editorMaxWidth: $editorMaxWidth,
                                     editorParentSpacing: $editorParentSpacing,
                                     editorChildSpacing: $editorChildSpacing,
                                     editorToobarOverlayOpacity: $editorToolbarOverlayOpacity,
                                     formatter: formatter())
                }
                Preferences.Section(bottomDivider: true) {
                    VStack(alignment: .center) {
                        Text("Appearance Font in Editor:")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.frame(width: 250, alignment: .trailing)
                } content: {
                    FontEditorAppearance(editorFontSize: $editorFontSize,
                                         editorCardTitleFontSize: $editorCardTitleFontSize,
                                         editorFontSizeHeadingOne: $editorFontSizeHeadingOne,
                                         editorHeaderOneSize: $editorHeaderOneSize,
                                         editorFontSizeHeadingTwo: $editorFontSizeHeadingTwo,
                                         editorHeaderTwoSize: $editorHeaderTwoSize,
                                         editorLineHeight: $editorLineHeight,
                                         editorLineHeightMultipleLine: $editorLineHeightMultipleLine,
                                         editorLineHeightHeading: $editorLineHeightHeading,
                                         formatter: formatter())
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
                            editorCardTitleFontSize = PreferencesManager.editorCardTitleFontSize
                            editorFontSizeHeadingOne = PreferencesManager.editorFontSizeHeadingOne
                            editorHeaderOneSize = PreferencesManager.editorHeaderOneSize
                            editorHeaderTwoSize = PreferencesManager.editorHeaderTwoSize
                            editorFontSizeHeadingTwo = PreferencesManager.editorFontSizeHeadingTwo
                            editorLineHeight = PreferencesManager.editorLineHeight
                            editorLineHeightMultipleLine = PreferencesManager.editorLineHeightMultipleLine
                            editorLineHeightHeading = PreferencesManager.editorLineHeightHeading
                        }
                    }
                }
            }
        }.frame(maxHeight: 500)
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
    @Binding var editorMinWidth: CGFloat
    @Binding var editorMaxWidth: CGFloat
    @Binding var editorParentSpacing: CGFloat
    @Binding var editorChildSpacing: CGFloat
    @Binding var editorToobarOverlayOpacity: Double
    var formatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $editorIsCentered) {
                Text("Center Text Editor")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([editorIsCentered].publisher.first()) {
                    PreferencesManager.editorIsCentered = $0
                }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leading percentage")
                    Text("Default: \(PreferencesManager.editorLeadingPercentageDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Header Top Padding")
                    Text("Default: \(PreferencesManager.editorHeaderTopPaddingDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorHeaderTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorHeaderTopPadding = editorHeaderTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal Content Top Padding")
                    Text("Default: \(PreferencesManager.editorJournalTopPaddingDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorJournalTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorJournalTopPadding = editorJournalTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Card Content Top Padding")
                    Text("Default: \(PreferencesManager.editorCardTopPaddingDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorCardTopPadding, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorCardTopPadding = editorCardTopPadding
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Editor Min Width")
                    Text("Default: \(PreferencesManager.editorMinWidthDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorMinWidth, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorMinWidth = editorMinWidth
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Editor Max Width")
                    Text("Default: \(PreferencesManager.editorMaxWidthDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorMaxWidth, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorMaxWidth = editorMaxWidth
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spacing between parent bullets")
                    Text("Default: \(PreferencesManager.editorParentSpacingDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorParentSpacing, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorParentSpacing = editorParentSpacing
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spacing between child bullets")
                    Text("Default: \(PreferencesManager.editorChildSpacingDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorChildSpacing, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorChildSpacing = editorChildSpacing
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toolbar Overlay Opacity")
                    Text("Default: \(PreferencesManager.editorToolbarOverlayOpacityDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorToobarOverlayOpacity, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorToolbarOverlayOpacity = editorToobarOverlayOpacity
                }.disableAutocorrection(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 50, height: 25, alignment: .center)
            }
        }
    }
}

struct FontEditorAppearance: View {
    @Binding var editorFontSize: CGFloat
    @Binding var editorCardTitleFontSize: CGFloat
    @Binding var editorFontSizeHeadingOne: CGFloat
    @Binding var editorHeaderOneSize: CGFloat
    @Binding var editorFontSizeHeadingTwo: CGFloat
    @Binding var editorHeaderTwoSize: CGFloat
    @Binding var editorLineHeight: CGFloat
    @Binding var editorLineHeightMultipleLine: CGFloat
    @Binding var editorLineHeightHeading: CGFloat

    var formatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Font Size")
                    Text("Default: \(PreferencesManager.editorFontSizeDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorFontSize, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSize = editorFontSize
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Card Title Font Size")
                    Text("Default: \(PreferencesManager.editorCardTitleFontSize)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorCardTitleFontSize, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorCardTitleFontSize = editorCardTitleFontSize
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heading One Font Size")
                    Text("Default: \(PreferencesManager.editorFontSizeHeadingOneDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorFontSizeHeadingOne, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSizeHeadingOne = editorFontSizeHeadingOne
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heading One Space Size")
                    Text("Default: \(PreferencesManager.editorHeaderOneSizeDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorHeaderOneSize, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorHeaderOneSize = editorHeaderOneSize
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heading Two Font Size")
                    Text("Default: \(PreferencesManager.editorFontSizeHeadingTwoDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorFontSizeHeadingTwo, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorFontSizeHeadingTwo = editorFontSizeHeadingTwo
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heading Two Space Size")
                    Text("Default: \(PreferencesManager.editorHeaderTwoSizeDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
                TextField("", value: $editorHeaderTwoSize, formatter: formatter) { _ in
                } onCommit: {
                    PreferencesManager.editorHeaderTwoSize = editorHeaderTwoSize
                }.disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50, height: 25, alignment: .center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Line Height for a line")
                    Text("Default: \(PreferencesManager.editorLineHeightDefault)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    TextField("", value: $editorLineHeight, formatter: formatter) { _ in
                    } onCommit: {
                        PreferencesManager.editorLineHeight = editorLineHeight
                    }.disableAutocorrection(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 50, height: 25, alignment: .center)
                }
            }
        }

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Line Height for Multiple Lines")
                Text("Default: \(PreferencesManager.editorLineHeightMultipleLineDefault)")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
            }
            TextField("", value: $editorLineHeightMultipleLine, formatter: formatter) { _ in
            } onCommit: {
                PreferencesManager.editorLineHeightMultipleLine = editorLineHeightMultipleLine
            }.disableAutocorrection(true)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50, height: 25, alignment: .center)
        }

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Line Height for Headers")
                Text("Default: \(PreferencesManager.editorLineHeightHeadingDefault)")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
            }
            TextField("", value: $editorLineHeightHeading, formatter: formatter) { _ in
            } onCommit: {
                PreferencesManager.editorLineHeightHeading = editorLineHeightHeading
            }.disableAutocorrection(true)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50, height: 25, alignment: .center)
        }
    }
}
