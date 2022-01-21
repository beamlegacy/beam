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

    func scoreLabel(_ label: String, _ score: Float?) -> some View {
        HStack {
            Text("\(label): ").font(.caption)
            if let score = score {
                Text("\(score)")
            } else {
                Text("-")
            }
        }
        .frame(width: 150, alignment: .center)
    }

    var body: some View {
        HStack {
            VStack {
                scoreLabel("Final", item.weightedScore)
                scoreLabel("Frecency", item.score)
                scoreLabel("Prefix boost", item.prefixScore)
            }

            VStack(alignment: .leading) {
                if let url = item.url?.absoluteString {
                    label(url, "url:")
                        .font(.headline)
                }
                if !item.text.isEmpty {
                    label(item.displayText, item.urlFields.contains(.text) ? "utext:" : "text:")
                }
                if let information = item.displayInformation {
                    label(information, item.urlFields.contains(.info) ? "uinfo:" : "info:")
                }
            }
        }
    }
}
