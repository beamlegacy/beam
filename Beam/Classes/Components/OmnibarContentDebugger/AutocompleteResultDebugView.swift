import Foundation
import SwiftUI

struct AutocompleteResultDebugView: View {
    var item: AutocompleteResult

    func label(_ text: String, _ label: String? = nil) -> some View {
        HStack {
            if let label = label {
                Text(label)
                    .frame(width: 30, alignment: .leading)
                    .font(.caption.italic())
            }

            Text(text)
                .lineLimit(1)
                .allowsTightening(true)
                .truncationMode(.tail)
                .help(text)
                .frame(alignment: .leading)
        }
    }

    func scoreLabel(_ score: Float?) -> some View {
        Group {
            if let score = score {
                Text("\(score)")
            } else {
                Text("-")
            }
        }
        .frame(width: 100, alignment: .center)
    }

    var body: some View {
        HStack {
            VStack {
                scoreLabel(item.score)
                scoreLabel(item.weightedScore)
                scoreLabel(item.prefixScore)
            }

            VStack(alignment: .leading) {
                if let url = item.url?.absoluteString {
                    label(url, "url:")
                        .font(.headline)
                }
                if let information = item.information {
                    label(information, item.urlFields.contains(.info) ? "uinfo:" : "info:")
                }
                if !item.text.isEmpty {
                    label(item.text, item.urlFields.contains(.text) ? "utext:" : "text:")
                }
            }
        }
    }
}
