//
//  DebugSection.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 06/08/2021.
//

import Foundation
import BeamCore

class DebugSection: Widget {
    var note: BeamNote
    let textLayer = CATextLayer()
    let separatorLayer = CALayer()
    let chevronLayer = CALayer()

    override var mainLayerName: String {
        "DebugSection"
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
        }
    }

    init(parent: Widget, note: BeamNote) {
        self.note = note

        super.init(parent: parent)

        textLayer.string = "Debug"
        textLayer.foregroundColor = BeamColor.DebugSection.sectionTitle.cgColor
        textLayer.fontSize = 12
        textLayer.font = BeamFont.semibold(size: 0).nsFont
        layer.addSublayer(textLayer)
        textLayer.frame = CGRect(origin: CGPoint(x: 20, y: 0), size: textLayer.preferredFrameSize())

        addLayer(ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        }), origin: CGPoint(x: 0, y: 0))

        separatorLayer.backgroundColor = BeamColor.DebugSection.separator.cgColor
        self.layer.addSublayer(separatorLayer)

        setupDebugInfoLayer()

        updateLayerVisibility()
    }

    override func updateRendering() {
        contentsFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 30)

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = availableWidth

        if open {
            guard let nodeIdLayer = layers["noteIdBtn"],
                  let noteDatabaseLayer = layers["noteDatabaseIdBtn"],
                  let defaultDatabaseIdLayer = layers["defaultDatabaseIdBtn"] else { return }
            computedIdealSize.height += nodeIdLayer.bounds.height +
                noteDatabaseLayer.bounds.height + defaultDatabaseIdLayer.bounds.height
        }
        updateLayerVisibility()
    }

    func updateLayerVisibility() {
        guard let nodeIdLayer = layers["noteIdBtn"],
              let noteDatabaseLayer = layers["noteDatabaseIdBtn"],
              let defaultDatabaseIdLayer = layers["defaultDatabaseIdBtn"] else { return }
        nodeIdLayer.layer.isHidden = !open
        noteDatabaseLayer.layer.isHidden = !open
        defaultDatabaseIdLayer.layer.isHidden = !open
        separatorLayer.isHidden = !open
    }

    private func setupDebugInfoLayer() {
        let nodeDatabaseId = self.note.documentStruct?.databaseId.uuidString ?? "nil"
        let defaultDatabaseId = DatabaseManager.defaultDatabase.id.uuidString
        let databaseTextColor = nodeDatabaseId == defaultDatabaseId ? BeamColor.Generic.text.nsColor : BeamColor.Shiraz.nsColor

        let noteIdLayer = Layer.text("ID: \(self.note.id.uuidString)", color: BeamColor.Generic.text.nsColor, size: 12)
        addLayer(ButtonLayer("noteIdBtn", noteIdLayer, activated: { [unowned self] in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(self.note.id.uuidString, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["noteIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 20))

        let databaseIdLayer = Layer.text("Database ID: \(nodeDatabaseId)", color: databaseTextColor, size: 12)
        addLayer(ButtonLayer("noteDatabaseIdBtn", databaseIdLayer, activated: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(nodeDatabaseId, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["noteDatabaseIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 40))

        let defaultDatabaseIdLayer = Layer.text("Default Database ID: \(defaultDatabaseId)", color: databaseTextColor, size: 12)
        addLayer(ButtonLayer("defaultDatabaseIdBtn", defaultDatabaseIdLayer, activated: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(defaultDatabaseId, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["defaultDatabaseIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 60))
    }

    var layerFrameXPad = CGFloat(25)
    func setupLayerFrame() {
        guard let nodeIdLayer = layers["noteIdBtn"],
              let noteDatabaseLayer = layers["noteDatabaseIdBtn"],
              let defaultDatabaseIdLayer = layers["defaultDatabaseIdBtn"] else { return }
        let space: CGFloat = 10.0

        nodeIdLayer.frame = CGRect(
            origin: CGPoint(x: nodeIdLayer.frame.origin.x, y: 20 + space),
            size: CGSize(
                width: nodeIdLayer.frame.width,
                height: nodeIdLayer.frame.height
            )
        )
        noteDatabaseLayer.frame = CGRect(
            origin: CGPoint(x: noteDatabaseLayer.frame.origin.x, y: (20*2)+space),
            size: CGSize(
                width: noteDatabaseLayer.frame.width,
                height: noteDatabaseLayer.frame.height
            )
        )
        defaultDatabaseIdLayer.frame = CGRect(
            origin: CGPoint(x: defaultDatabaseIdLayer.frame.origin.x, y: (20*3)+space),
            size: CGSize(
                width: defaultDatabaseIdLayer.frame.width,
                height: defaultDatabaseIdLayer.frame.height
            )
        )
    }

    override func updateSubLayersLayout() {
        super.updateSubLayersLayout()

        CATransaction.disableAnimations {
            setupLayerFrame()
            separatorLayer.frame = CGRect(x: 0, y: textLayer.frame.maxY + 4, width: 560, height: 1)
        }
    }
}
