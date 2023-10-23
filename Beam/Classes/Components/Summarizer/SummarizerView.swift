//
//  SummarizerView.swift
//  Beam
//
//  Created by Stef Kors on 23/10/2023.
//

import SwiftUI

struct SummarizerView: View {

    var text: String?

    private var onClose: () -> Void

    let preferredWidth: CGFloat = 368.0

    init(text: String?, onCloseButtonTap: @escaping () -> Void) {
        self.text = text
        self.onClose = onCloseButtonTap
    }

    var body: some View {
        ZStack(alignment: .center) {
            if let text {
                VStack(alignment: .leading) {
                    Text("Summary:").bold()
                        .padding(.bottom, 12)
                    Text(text.summarize(numberOfSentences: 2))

                    Spacer()
                }
            } else {
                ProgressView()
            }
        }
        .font(.body)
        .padding()
        .frame(width: preferredWidth, height: 370)
        .background(BeamColor.Generic.secondaryBackground.swiftUI)
        .cornerRadius(10)
    }
}

#Preview {
    SummarizerView(text: "summary") {
        // callback
    }
}
