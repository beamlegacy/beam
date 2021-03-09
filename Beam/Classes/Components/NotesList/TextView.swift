import SwiftUI

struct TextView: NSViewRepresentable {
    @Binding var text: NSAttributedString

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ScrollableTextView {
        var views: NSArray?
        Bundle.main.loadNibNamed("ScrollableTextView", owner: nil, topLevelObjects: &views)
        let scrollableTextView = views!.compactMap({ $0 as? ScrollableTextView }).first!
        scrollableTextView.textView.delegate = context.coordinator
        return scrollableTextView
    }

    func updateNSView(_ nsView: ScrollableTextView, context: Context) {
        guard let textStorage = nsView.textView.layoutManager?.textStorage, textStorage != text else { return }

        nsView.textView.layoutManager?.replaceTextStorage(NSTextStorage(attributedString: text))
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: TextView

        init(_ textView: TextView) {
            self.parent = textView
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.layoutManager?.textStorage else { return }

            self.parent.text = textStorage
        }
    }

    final class InternalTextView: NSTextView {
        override var intrinsicContentSize: NSSize {
            super.intrinsicContentSize
        }
    }
}

struct TextView_Previews: PreviewProvider {
    static var previews: some View {
        let quote = String.loremIpsum
        let font = NSFont.systemFont(ofSize: 12)
        let attributes = [NSAttributedString.Key.font: font,
                          .foregroundColor: NSColor.red]
        let attributedQuote = NSAttributedString(string: quote, attributes: attributes)

        return TextView(text: .constant(attributedQuote))
    }
}
