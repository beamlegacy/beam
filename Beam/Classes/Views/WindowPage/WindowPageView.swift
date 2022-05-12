//
//  WindowPageView.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import SwiftUI

struct WindowPageView: View {
    var page: WindowPage

    var body: some View {
        VStack(spacing: BeamSpacing._400) {
            if let displayTitle = page.displayTitle {
                HStack {
                    Text(displayTitle)
                        .font(BeamFont.semibold(size: 26).swiftUI)
                    Spacer()
                }
                .padding(.top, 85)
            }
            page.contentView()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct WindowPageView_Previews: PreviewProvider {
    static var previews: some View {
        WindowPageView(page: WindowPage(id: .allNotes, displayTitle: "Preview Page") {
            AnyView(Rectangle())
        })
    }
}
