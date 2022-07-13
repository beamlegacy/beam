//
//  GeneralPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences

let GeneralPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .general, title: "General", imageName: "preferences-general-on") {
    GeneralPreferencesView()
}

struct GeneralPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: false) {
                VStack(alignment: .center) {
                    Text("Appearance:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.frame(width: 250, height: 70, alignment: .trailing)
            } content: {
                AppearanceSection()
            }

            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                NewWindowLaunchOption()
            }

            Preferences.Section(bottomDivider: true) {
                Text("Accessibility:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                AccessibilitySection()
            }
//            Preferences.Section {
//                Text("Updates:")
//                    .font(BeamFont.regular(size: 13).swiftUI)
//                    .foregroundColor(BeamColor.Generic.text.swiftUI)
//            } content: {
//                UpdatesSection()
//            }

        }
    }
}

struct GeneralPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralPreferencesView()
    }
}

private struct NewWindowLaunchOption: View {

    @State private var selectedDefaultWindowMode: PreferencesManager.PreferencesDefaultWindowMode = PreferencesManager.defaultWindowMode

    private var withOpenedTabsBinding: Binding<Bool> {
        Binding<Bool>(
            get: { selectedDefaultWindowMode == .webTabs },
            set: { selectedDefaultWindowMode = $0 ? .webTabs : .journal }
        )
    }
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: withOpenedTabsBinding) {
                Text("Start beam with opened tabs")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            Text("Always start on the web if there are pinned \nor opened tabs")
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(minHeight: 30)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .padding(.leading, 18)
        }
        .onChange(of: selectedDefaultWindowMode) {
            PreferencesManager.defaultWindowMode = $0
        }

    }
}

struct AppearanceSection: View {
    @State private var beamAppearence = PreferencesManager.shared.beamAppearance

    var body: some View {
        HStack(spacing: 13) {
            AppearanceView(beamAppearence: $beamAppearence, beamAppearenceName: "Light", beamAppearenceImageName: "preferences-general_appearance_light", beamAppearenceDefault: .light)
            AppearanceView(beamAppearence: $beamAppearence, beamAppearenceName: "Dark", beamAppearenceImageName: "preferences-general_appearance_dark", beamAppearenceDefault: .dark)
            AppearanceView(beamAppearence: $beamAppearence, beamAppearenceName: "System", beamAppearenceImageName: "preferences-general_appearance_system", beamAppearenceDefault: .system)
        }
    }
}

struct AppearanceView: View {
    @Binding var beamAppearence: BeamAppearance
    var beamAppearenceName: String
    var beamAppearenceImageName: String
    var beamAppearenceDefault: BeamAppearance

    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                set(beamAppearance: beamAppearenceDefault)
            }, label: {
                VStack {
                    Image(beamAppearenceImageName)
                        .scaledToFit()
                        .cornerRadius(7)
                        .if(beamAppearence == beamAppearenceDefault) {
                            $0.overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.blue, lineWidth: 4)
                            )
                        }
                    Text(beamAppearenceName)
                        .font(BeamFont.medium(size: 10).swiftUI)
                        .foregroundColor(beamAppearence == beamAppearenceDefault ?
                                            BeamColor.Bluetiful.swiftUI : BeamColor.Generic.subtitle.swiftUI)
                }
            }).buttonStyle(PlainButtonStyle())
        }
    }

    private func set(beamAppearance: BeamAppearance) {
        self.beamAppearence = beamAppearance
        PreferencesManager.shared.beamAppearance = beamAppearance
    }
}

struct AccessibilitySection: View {
//    @State private var isPickerEnabled: Bool = PreferencesManager.isFontMinOnPreference
//    @State private var fontSizeIndex = PreferencesManager.fontSizeIndexPreference
    @State private var isTabToHighlightOn = PreferencesManager.isTabToHighlightOn

    var body: some View {
//        HStack {
//        Toggle(isOn: $isPickerEnabled) {
//            Text("Never use font sizes smaller than")
//        }.toggleStyle(CheckboxToggleStyle())
//            .font(BeamFont.regular(size: 13).swiftUI)
//            .foregroundColor(BeamColor.Generic.text.swiftUI)
//            Picker("", selection: $fontSizeIndex) {
//                ForEach(PreferencesManager.shared.fontSizes) {
//                    Text("\($0)")
//                }
//            }.labelsHidden()
//            .frame(width: 45, height: 20, alignment: .center)
//            .disabled(!isPickerEnabled)
//            .onReceive([self.fontSizeIndex].publisher.first()) { value in
//                PreferencesManager.fontSizeIndexPreference = value
//            }
//        }

        Toggle(isOn: $isTabToHighlightOn) {
            Text("Press Tab to highlight each item on a web page")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isTabToHighlightOn, perform: {
                PreferencesManager.isTabToHighlightOn = $0
            })

        VStack {
            Text("Option-Tab to highlights each item.")
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .padding(.leading, 18)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
    }
}

struct UpdatesSection: View {
    @State private var isAutoUpdateOn = PreferencesManager.isAutoUpdateOn

    var body: some View {
        Toggle(isOn: $isAutoUpdateOn) {
            Text("Automatically update Beam")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isAutoUpdateOn, perform: {
                PreferencesManager.isAutoUpdateOn = $0
            })
    }
}
