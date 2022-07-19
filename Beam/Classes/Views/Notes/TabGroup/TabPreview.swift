//
//  TabPreview.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 09/06/2022.
//

import SwiftUI
import BeamCore

struct TabPreview: View {

    let tab: TabGroupBeamObject.PageInfo

    @State private var isHovered: Bool = false
    @State private var favicon: Image?
    var placeholderTintColor: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            preview
                .frame(width: 176, height: 114)
                .cornerRadius(4)
                .background(
                    RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                .padding(2)
            HStack(spacing: 4) {
                Group {
                    if let favicon = favicon {
                        favicon
                            .resizable()
                    } else {
                        Image("field-web")
                            .renderingMode(.template)
                            .resizable()
                            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                    }
                }
                .frame(width: 16, height: 16)
                Text(tab.title)
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.Niobium.swiftUI)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 36, alignment: .center)
            .padding(.horizontal, 10)
            .blendModeLightMultiplyDarkScreen()
        }
        .frame(width: 180)
        .background(background)
        .animation(nil)
        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        .onAppear {
            FaviconProvider.shared.favicon(fromURL: tab.url) { favicon in
                if let nsImage = favicon?.image {
                    self.favicon = Image(nsImage: nsImage)
                }
            }
        }
    }

    @ViewBuilder private var background: some View {
        VisualEffectView(material: .hudWindow)
            .background(colorScheme == .light ? BeamColor.Mercury.swiftUI.opacity(0.7) : BeamColor.AlphaGray.swiftUI.opacity(0.5))
            .cornerRadius(6.0)
            .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5), alignment: .center)
            .shadow(color: .black.opacity(0.16), radius: 15, x: 0, y: 5)
    }

    @ViewBuilder private var preview: some View {
        if let capture = tab.snapshot, let image = NSImage(data: capture) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                previewBackground
                placeholderTintColor.opacity(0.05)
                Image("tabs-group_thumbnail")
                    .foregroundColor(placeholderTintColor.opacity(colorScheme == .dark ? 0.4 : 0.3))
                    .blendModeLightMultiplyDarkScreen()
            }
        }
    }

    private var previewBackground: Color {
        switch colorScheme {
        case .dark:
            return BeamColor.Mercury.swiftUI
        default:
            return .white
        }
    }
}

struct TabPreview_Previews: PreviewProvider {
    static var previews: some View {
        TabPreview(tab: TabGroupBeamObject.PageInfo(id: UUID(), url: URL(string: "https://fr.wikipedia.org/wiki/Jean_Baudrillard")!, title: "Jean Baudrillard - Wikipedia"), placeholderTintColor: TabGroupingColor.DesignColor.pink.color.swiftUI)
            .padding()
            .background(Color.green)
    }
}

extension TabGroupBeamObject {
    static var demoGroup: TabGroupBeamObject {
        let tab1 = TabGroupBeamObject.PageInfo(id: UUID(), url: URL(string: "https://fr.wikipedia.org/wiki/Jean_Baudrillard")!, title: "Jean Baudrillard - Wikipedia", snapshot: NSImage(named: "amazon")?.jpegRepresentation)

        let tab2 = TabGroupBeamObject.PageInfo(id: UUID(), url: URL(string: "https://fr.wikipedia.org/wiki/Postmodernit%C3%A9")!, title: "Postmodernité  - Wikipedia", snapshot: nil)

        let tab3 = TabGroupBeamObject.PageInfo(id: UUID(), url: URL(string: "https://fr.wikipedia.org/wiki/Le_Syst%C3%A8me_des_objets")!, title: "Le Système de objets - Wikipedia", snapshot: NSImage(named: "amazon")?.jpegRepresentation)

        let group = TabGroupBeamObject(id: UUID(), title: "Baudrillard", color: TabGroupingColor(designColor: .blue), pages: [tab1, tab2, tab3], isLocked: true)
        return group
    }
}
