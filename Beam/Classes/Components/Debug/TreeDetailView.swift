//
//  TreeDetailView.swift
//  Beam
//
//  Created by Sébastien Metrot on 09/06/2022.
//

import Foundation
import AppKit
import BeamCore

class TreeDetailView: NSView {
    var detailedItem: DataTreeNode?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadIfItemIsDetailed(_ node: DataTreeNode?) {
        guard detailedItem?.id != node?.id || (node?.reloadOnChange ?? true) else { return }
        setupFor(node)
    }

    func setupFor(_ node: DataTreeNode?) {
        clear()

        detailedItem = node

        guard let node = node else {
            setupPlaceholder()
            return
        }

        if let documentNode = node as? DocumentTreeNode {
            let scrollView = NSScrollView()
            scrollView.frame = NSRect(origin: NSPoint(), size: self.frame.size)
            scrollView.autoresizingMask = [.width, .height]

            setupEditor(forDocument: documentNode, in: scrollView)

            let stackView = NSStackView(frame: CGRect(origin: .zero, size: frame.size))
            stackView.orientation = .vertical
            stackView.autoresizingMask = [.width, .height]
            addSubview(stackView)

            let displayType = NSSegmentedControl(labels: ["Note", "JSON", "Synced JSON"], trackingMode: .selectOne, target: self, action: #selector(displayTypeChanged))
            displayType.selectedSegment = 0
            displayType.autoresizingMask = [.width, .height]
            displayType.sizeToFit()

            stackView.distribution = .fillProportionally

            stackView.addArrangedSubview(displayType)
            stackView.addArrangedSubview(scrollView)

            return
        } else if let managerNode = node as? GenericManagerTreeNode, let manager = managerNode.manager {
            let view = GenericManagerTableView(manager: manager, frame: CGRect(origin: .zero, size: frame.size))
            view.autoresizingMask = [.width, .height]

            addSubview(view)

            return
        }

        setupPlaceholder()
    }

    func setupEditor(forDocument documentNode: DocumentTreeNode, in scrollView: NSScrollView) {
        if let document = documentNode.document, let note = BeamNote.getFetchedNote(documentNode.id) ?? (try? BeamNote.instanciateNote(document)) {
            let editor = BeamTextEdit(root: note, journalMode: false, enableDelayedInit: true, frame: NSRect(origin: .zero, size: CGSize(width: frame.width, height: BeamTextEdit.minimumEmptyEditorHeight)))
            editor.autoresizingMask = [.width]
            editor.topOffset = 200

            scrollView.documentView = editor
        }
    }

    @objc func displayTypeChanged(sender: Any) {
        guard let control = sender as? NSSegmentedControl,
                let documentNode = detailedItem as? DocumentTreeNode,
                let scrollView = control.superview?.subviews[1] as? NSScrollView
        else { return }
        switch control.indexOfSelectedItem {
        case 0:
            setupEditor(forDocument: documentNode, in: scrollView)
        case 1:
            setupJSONView(forDocument: documentNode, in: scrollView)
        case 2:
            setupSyncedJSONView(forDocument: documentNode, in: scrollView)
        default:
            break
        }
    }

    func setupTextView(string: String, in scrollView: NSScrollView) {
        let textView = NSTextView(frame: CGRect(origin: .zero, size: CGSize(width: frame.width, height: 200)))
        textView.string = string
        textView.autoresizingMask = [.width]
        textView.sizeToFit()
        scrollView.documentView = textView
    }

    func setupJSONView(forDocument documentNode: DocumentTreeNode, in scrollView: NSScrollView) {
        guard let string = documentNode.document?.data.asString else { return }
        setupTextView(string: string, in: scrollView)
    }

    func setupSyncedJSONView(forDocument documentNode: DocumentTreeNode, in scrollView: NSScrollView) {
        guard let string = documentNode.document?.previousSavedObject?.data.asString else { return }
        setupTextView(string: string, in: scrollView)
    }

    func setupPlaceholder() {
        let placeholder = NSTextView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        placeholder.isEditable = false
        placeholder.autoresizingMask = [.width, .height]
        addSubview(placeholder)
    }

    func clear() {
        detailedItem = nil
        for view in subviews {
            view.removeFromSuperview()
        }
    }
}
