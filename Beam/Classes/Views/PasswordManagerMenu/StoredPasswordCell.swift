//
//  StoredPasswordCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 30/03/2021.
//

import SwiftUI

struct StoredPasswordCell: View {
    let host: URL
    let username: String
    let searchString: String?
    let onChange: (PasswordManagerMenuCellState) -> Void

    @State private var faviconState: FaviconState = .loading

    enum FaviconState {
        case loading
        case generic
        case available(NSImage)
    }

    var body: some View {
        PasswordManagerMenuCell(onChange: onChange) {
            HStack {
                switch faviconState {
                case .available(let favicon):
                    Image(nsImage: favicon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                case .generic:
                    Icon(name: "field-web", color: BeamColor.Niobium.swiftUI)
                default:
                    Color.clear
                        .frame(width: 16, height: 16)
                }
                VStack(alignment: .leading) {
                    if let searchString = searchString {
                        StyledText(verbatim: host.minimizedHost)
                            .style(.semibold()) { $0.ranges(of: searchString, options: .caseInsensitive) }
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                        StyledText(verbatim: username)
                            .style(.semibold()) { $0.ranges(of: searchString, options: .caseInsensitive) }
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    } else {
                        Text(username)
                        Text("••••••••••••")
                    }
                }
            }
        }
        .onAppear(perform: {
            FaviconProvider.shared.imageForUrl(host) {
                if let favicon = $0 {
                    self.faviconState = .available(favicon)
                } else {
                    self.faviconState = .generic
                }
            }
        })
    }
}

struct StoredPasswordCell_Previews: PreviewProvider {
    static var previews: some View {
        StoredPasswordCell(host: URL(string: "https://beamapp.co")!, username: "beam@beamapp.co", searchString: nil) { _ in }
    }
}
