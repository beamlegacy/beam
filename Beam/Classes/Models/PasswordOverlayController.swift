//
//  PasswordOverlayController.swift
//  Beam
//
//  Created by Beam on 23/03/2021.
//

import Foundation

class PasswordOverlayController {
    private let webView: WKWebView
    private let passwordManager: PasswordManager
    private var overlay: PasswordOverlayView?
    private let decoder: JSONDecoder
    private var inputFields: [String: AutofillInputField]

    init(webView: WKWebView, passwordManager: PasswordManager = .shared) {
        self.webView = webView
        self.passwordManager = passwordManager
        decoder = JSONDecoder()
        inputFields = [:]
    }

    func detectInputFields() {
        webView.evaluateJavaScript("beam_sendTextFields();") { _, error in
            if let error = error {
                Logger.shared.logError(String(describing: error), category: .javascript)
            }
        }
    }

    func updateInputFields(with jsResult: String) {
        guard let jsonData = jsResult.data(using: .utf8) else { return }
        let elements: [DOMInputElement]
        do {
            elements = try decoder.decode([DOMInputElement].self, from: jsonData)
            Logger.shared.logDebug("🔑 decoded: \(elements)")
        } catch {
            Logger.shared.logError(String(describing: error), category: .javascript)
            return
        }

        let passwordRelatedFields = passwordManager.autofillFields(from: elements)
        let initialIds = Set(inputFields.keys)
        let finalIds = Set(passwordRelatedFields.map(\.id))
        let addedIds = finalIds.subtracting(initialIds)
        let removedIds = initialIds.subtracting(finalIds)

        if !addedIds.isEmpty {
            let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
            let focusScript = "beam_installFocusHandlers('[\(formattedList)]');"
            webView.evaluateJavaScript(focusScript)
            #if false
            let script = "beam_getElementRects('[\(formattedList)]');"
            webView.evaluateJavaScript(script) { jsResult, _ in
                if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData) {
                    var addedInputFields = passwordRelatedFields.reduce(into: [String: AutofillInputField]()) { (dict, field) in
                        if addedIds.contains(field.id) {
                            dict[field.id] = field
                        }
                    }
                    for (id, rect) in zip(addedIds, rects) {
                        guard let rect = rect else { continue }
                        addedInputFields[id]?.bounds = rect.rect
                    }
                    DispatchQueue.main.async {
                        self.updateOverlay(adding: addedInputFields, removing: removedIds)
                        self.inputFields.merge(addedInputFields) { (_, new) in new }
                    }
                }
            }
            #endif
        }
    }

    func updateInputFocus(for elementId: String, becomingActive: Bool) {
        Logger.shared.logDebug("Text field \(elementId) changed focus to \(becomingActive).")
    }

    func updateOverlay(adding addedFields: [String: AutofillInputField], removing removedIds: Set<String>) {
        if !addedFields.isEmpty && overlay == nil {
            let overlay = PasswordOverlayView(frame: webView.bounds) // FIXME: use content size
            let overlayEnclosingView = FlippedView(frame: webView.bounds)
            overlayEnclosingView.autoresizingMask = [.width, .height]
            overlayEnclosingView.addSubview(overlay)
            webView.superview?.addSubview(overlayEnclosingView)
            self.overlay = overlay
        }
        guard let overlay = overlay else { return }
        removedIds.forEach { id in
            overlay.removeButton(id: id)
        }
        addedFields.forEach { (_, field) in
            overlay.addButton(inputField: field)
        }
    }

    func updateOverlay(moving movedFields: [String: AutofillInputField]) {
        movedFields.values.forEach { field in
            overlay?.moveButton(inputField: field)
        }
    }

    func updateScrollPosition(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        DispatchQueue.main.async {
            self.overlay?.frame.origin = CGPoint(x: x, y: -y)
            Logger.shared.logDebug("scrolled to \(x) \(y) \(width) \(height)")
        }
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        let ids = inputFields.keys
        let formattedList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let script = "beam_getElementRects('[\(formattedList)]');"
        webView.evaluateJavaScript(script) { jsResult, _ in
            if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData) {
                for (id, rect) in zip(ids, rects) {
                    guard let rect = rect else { continue }
                    self.inputFields[id]?.bounds = rect.rect
                }
                DispatchQueue.main.async {
                    self.updateOverlay(moving: self.inputFields)
                }
            }
        }
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class PasswordOverlayView: FlippedView {
    private var buttons = [String: NSView]()

    func addButton(inputField: AutofillInputField) {
        guard let inputBounds = inputField.bounds else { return }
        let view = NSButton(title: "autofill", target: nil, action: nil)
        addSubview(view)
        view.frame.origin = inputBounds.origin
        buttons[inputField.id] = view
    }

    func removeButton(id: String) {
        if let view = buttons[id] {
            view.removeFromSuperview()
            buttons[id] = nil
        }
    }

    func moveButton(inputField: AutofillInputField) {
        guard let view = buttons[inputField.id], let inputBounds = inputField.bounds else { return }
        view.frame.origin = inputBounds.origin
    }
}
