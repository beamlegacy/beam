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
    let onChange: (PasswordManagerMenuCellState) -> Void

    @State private var faviconState: FaviconState = .loading

    enum FaviconState {
        case loading
        case generic
        case available(NSImage)
    }

    var body: some View {
        PasswordManagerMenuCell(height: 56, onChange: onChange) {
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
                    Text(username)
                        .offset(y: 10)
                        .padding(.bottom, 4)
                    Text("••••••••••••")
                        .padding(.bottom, 10)
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
        StoredPasswordCell(host: URL(string: "https://beamapp.co")!, username: "beam@beamapp.co") { _ in }
    }
}
