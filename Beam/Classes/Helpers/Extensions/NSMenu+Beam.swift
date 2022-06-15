import AppKit
import BeamCore

final class HandlerMenuItem: NSMenuItem {
    typealias Handler = (NSMenuItem) -> Void

    let handler: Handler

    init(title: String, keyEquivalent: String = "", handler: @escaping Handler) {
        self.handler = handler
        super.init(title: title, action: #selector(performAction(_:)), keyEquivalent: keyEquivalent)
        self.target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performAction(_ item: NSMenuItem) {
        handler(item)
    }
}

extension NSMenu {

    @discardableResult
    func addItem(withTitle title: String, keyEquivalent: String = "", handler: @escaping HandlerMenuItem.Handler) -> NSMenuItem {
        let item = HandlerMenuItem(title: title, keyEquivalent: keyEquivalent, handler: handler)
        addItem(item)
        return item
    }

}
