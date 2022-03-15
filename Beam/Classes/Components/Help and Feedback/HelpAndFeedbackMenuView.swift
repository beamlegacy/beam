//
//  HelpAndFeedbackMenuView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 14/09/2021.
//

import SwiftUI

enum HelpMenuSection: String, CaseIterable, Identifiable {
    case shortcuts
    case featureRequest
    case bugReport
    case twitter

    var id: HelpMenuSection {
        return self
    }

    var text: String {
        switch self {
        case .shortcuts:
            return "Shortcuts"
        case .featureRequest:
            return "Feature Request"
        case .bugReport:
            return "Report a bug"
        case .twitter:
            return "Follow @getonbeam"
        }
    }

    var subtitle: String? {
        switch self {
        case .shortcuts:
            return "Beam like a pro"
        case .featureRequest:
            return "Submit an idea"
        case .bugReport:
            return "Found a bug? Help us squash it"
        case .twitter:
            return nil
        }
    }

    var iconName: String {
        switch self {
        case .shortcuts:
            return "help-shortcuts"
        case .featureRequest:
            return "help-featurerequest"
        case .bugReport:
            return "help-bug"
        case .twitter:
            return "help-twitter"
        }
    }

    var url: URL? {
        switch self {
        case .shortcuts:
            return nil
        case .featureRequest:
            return URL(string: "https://beamapp.canny.io/feature-r")
        case .bugReport:
            return URL(string: "https://beamapp.canny.io/bugs")
        case .twitter:
            return URL(string: "https://twitter.com/getonbeam")
        }
    }
}

struct HelpAndFeedbackMenuView: View {

    @State private var hoveredSection: HelpMenuSection?
    @EnvironmentObject var state: BeamState
    @Environment(\.colorScheme) var colorScheme
    weak var window: PopoverWindow?

    static let menuWidth: CGFloat = 284.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Help & Feedback")
                    .font(BeamFont.regular(size: 13).swiftUI)
                Spacer()
                ButtonLabel(icon: "tool-close", customStyle: ButtonLabelStyle(horizontalPadding: -2, activeBackgroundColor: Color.clear)) {
                    window?.close()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 41)

            PopupSeparator()
                .padding(.vertical, 0)

            ForEach(HelpMenuSection.allCases) { section in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 0) {
                            Icon(name: section.iconName, width: 16, color: BeamColor.Niobium.swiftUI)
                                .padding(.leading, 6)
                                .padding(.trailing, 8)

                            Text(section.text)
                                .foregroundColor(BeamColor.Niobium.swiftUI)
                                .font(BeamFont.medium(size: 12).swiftUI)

                            Spacer()
                        }

                        if let subtitle = section.subtitle {
                            Text(subtitle)
                                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                                .font(BeamFont.regular(size: 11).swiftUI)
                                .padding(.leading, 30)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.top, (section.subtitle != nil) ? 10 : 12)
                .padding(.bottom, (section.subtitle != nil) ? 11 : 12)
                .background(hoveredSection == section ? BeamColor.Nero.swiftUI : backgroundColor)
                .onHover(perform: { hovering in
                    if hovering {
                        hoveredSection = section
                    } else if hoveredSection == section {
                        hoveredSection = nil
                    }
                })
                .onTapGesture {
                    if let link = section.url {
                        state.mode = .web
                        _ = state.createTab(withURL: link, originalQuery: nil)
                    } else {
                        state.navigateToPage(.shortcutsWindowPage)
                    }
                    window?.close()
                }

                if let last = HelpMenuSection.allCases.last, last != section {
                    PopupSeparator()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 0)
                }
            }
        }
        .frame(width: Self.menuWidth)
        .background(backgroundColor)
        .cornerRadius(10)
    }

    private var backgroundColor: Color {
        BeamColor.Generic.secondaryBackground.swiftUI
    }
}

struct HelpAndFeedbackMenuView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HelpAndFeedbackMenuView()
            HelpAndFeedbackMenuView()
                .preferredColorScheme(.dark)
        }
    }
}
