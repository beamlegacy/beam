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
            }.padding(.horizontal, 12)
            .frame(height: 41)
            Separator(horizontal: true)
                .padding(.vertical, 0)
                .padding(.horizontal, 12)
            ForEach(HelpMenuSection.allCases) { section in
                VStack(spacing: 0) {
                    HStack {
                        Text(section.text)
                            .foregroundColor(BeamColor.Niobium.swiftUI)
                            .font(BeamFont.regular(size: 12).swiftUI)
                        Spacer()
                    }.padding(.horizontal, 24)
                    .padding(.top, 10)
                    Spacer()
                    if let last = HelpMenuSection.allCases.last, last != section {
                        Separator(horizontal: true)
                            .padding(.vertical, 0)
                            .padding(.horizontal, 12)
                    }
                }.frame(height: 39)
                .onHover(perform: { hovering in
                    if hovering {
                        hoveredSection = section
                    } else if hoveredSection == section {
                        hoveredSection = nil
                    }
                })
                .background(hoveredSection == section ? BeamColor.Nero.swiftUI : backgroundColor)
                .animation(.easeIn, value: hoveredSection)
                .onTapGesture {
                    if let link = section.url {
                        state.mode = .web
                        _ = state.createTab(withURL: link, originalQuery: nil)
                    } else {
                        state.navigateToPage(.shortcutsWindowPage)
                    }
                    window?.close()
                }
            }
        }.frame(width: Self.menuWidth)
        .background(backgroundColor)
        .cornerRadius(6)
    }

    private var backgroundColor: Color {
        BeamColor.Generic.background.swiftUI
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
