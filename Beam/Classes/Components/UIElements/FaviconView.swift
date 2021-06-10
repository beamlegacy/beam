//
//  FaviconView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/06/2021.
//

import SwiftUI

struct FaviconView: View {
    let url: URL?

    @State private var faviconState: FaviconState = .loading

    enum FaviconState {
        case loading
        case generic
        case available(NSImage)
    }

    var body: some View {
        VStack {
            switch faviconState {
            case .available(let favicon):
                Image(nsImage: favicon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            case .generic:
                Icon(name: "field-web", color: BeamColor.Niobium.swiftUI)
                    .padding(.trailing, 4)
            default:
                Color.clear
                    .frame(width: 16, height: 16)
            }
        }.onAppear(perform: {
            guard let url = url else {
                self.faviconState = .generic
                return
            }
            FaviconProvider.shared.imageForUrl(url) {
                if let favicon = $0 {
                    self.faviconState = .available(favicon)
                } else {
                    self.faviconState = .generic
                }
            }
        })
    }
}

struct FaviconView_Previews: PreviewProvider {
    static var previews: some View {
        FaviconView(url: URL(string: "www.beamapp.co")!)
    }
}
