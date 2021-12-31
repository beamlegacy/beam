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

    let savingLayer = CATextLayer()
    let updatesLayer = CATextLayer()
    let updateAttemptsLayer = CATextLayer()

    override var mainLayerName: String {
        "DebugSection"
    }

    override var contentsScale: CGFloat {
        didSet {
            textLayer.contentsScale = contentsScale
            savingLayer.contentsScale = contentsScale
            updatesLayer.contentsScale = contentsScale
            updateAttemptsLayer.contentsScale = contentsScale
        }
    }

    private func setupTextLayer(_ layer: CATextLayer, name: String, string: String, position: CGPoint) {
        layer.name = name
        layer.string = string
        layer.foregroundColor = BeamColor.DebugSection.sectionTitle.cgColor
        layer.fontSize = 12
        layer.font = BeamFont.semibold(size: 0).nsFont
        layer.frame = CGRect(origin: position, size: textLayer.preferredFrameSize())
    }

    init(parent: Widget, note: BeamNote, availableWidth: CGFloat) {
        self.note = note

        super.init(parent: parent, availableWidth: availableWidth)
        setupTextLayer(textLayer, name: "Debug", string: "Debug", position: CGPoint(x: 20, y: 0))
        setupTextLayer(savingLayer, name: "saving", string: "-", position: CGPoint(x: 100, y: 0))
        setupTextLayer(updatesLayer, name: "updates", string: "-", position: CGPoint(x: 200, y: 0))
        setupTextLayer(updateAttemptsLayer, name: "update attempts", string: "-", position: CGPoint(x: 300, y: 0))

        layer.addSublayer(textLayer)
        layer.addSublayer(savingLayer)
        layer.addSublayer(updatesLayer)
        layer.addSublayer(updateAttemptsLayer)

        let chevron = ChevronButton("chevron", open: open, changed: { [unowned self] value in
            self.open = value
        })
        chevron.setAccessibilityIdentifier("debug_arrow")
        addLayer(chevron, origin: CGPoint(x: 0, y: 0))

        separatorLayer.backgroundColor = BeamColor.DebugSection.separator.cgColor
        self.layer.addSublayer(separatorLayer)

        setupDebugInfoLayer()

        updateLayerVisibility()

        note.$saving.sink { [weak self] val in
            let value = val.load(ordering: .relaxed)
            guard let self = self else { return }
            let deadline = value ? DispatchTime.now() : DispatchTime.now() + 0.5
            DispatchQueue.main.asyncAfter(deadline: deadline) {
                self.savingLayer.string = value ? "saving" : ""
                self.savingLayer.frame = CGRect(origin: self.savingLayer.frame.origin, size: self.savingLayer.preferredFrameSize())
            }
        }.store(in: &scope)

        note.$updateAttempts.sink { [weak self] value in
            guard let self = self else { return }
            self.updateAttemptsLayer.string = "update attemps: \(value)"
            self.updateAttemptsLayer.frame = CGRect(origin: self.updateAttemptsLayer.frame.origin, size: self.updateAttemptsLayer.preferredFrameSize())
        }.store(in: &scope)

        note.$updates.sink { [weak self] value in
            guard let self = self else { return }
            self.updatesLayer.string = "updates: \(value)"
            self.updatesLayer.frame = CGRect(origin: self.updatesLayer.frame.origin, size: self.updatesLayer.preferredFrameSize())
        }.store(in: &scope)
    }

    override func updateRendering() -> CGFloat {
        if open {
            guard let nodeIdLayer = layers["noteIdBtn"],
                  let noteDatabaseLayer = layers["noteDatabaseIdBtn"],
                  let defaultDatabaseIdLayer = layers["defaultDatabaseIdBtn"],
                  let previousChecksumLayer = layers["previousChecksum"] else { return 30 }
            return 30 + nodeIdLayer.bounds.height +
                noteDatabaseLayer.bounds.height +
                defaultDatabaseIdLayer.bounds.height +
                previousChecksumLayer.bounds.height
        }
        return 30
    }

    func updateLayerVisibility() {
        guard let nodeIdLayer = layers["noteIdBtn"],
              let noteDatabaseLayer = layers["noteDatabaseIdBtn"],
              let defaultDatabaseIdLayer = layers["defaultDatabaseIdBtn"],
              let previousChecksumLayer = layers["previousChecksum"] else { return }
        nodeIdLayer.layer.isHidden = !open
        noteDatabaseLayer.layer.isHidden = !open
        defaultDatabaseIdLayer.layer.isHidden = !open
        previousChecksumLayer.layer.isHidden = !open
        separatorLayer.isHidden = !open

    }

    private func setupDebugInfoLayer() {
        let nodeDatabaseId = self.note.documentStruct?.databaseId.uuidString ?? "-"
        let previousChecksum = self.note.documentStruct?.previousChecksum ?? "-"

        let defaultDatabaseId = DatabaseManager.defaultDatabase.id.uuidString
        let databaseTextColor = nodeDatabaseId == defaultDatabaseId ? BeamColor.Generic.text.nsColor : BeamColor.Shiraz.nsColor

        let noteIdLayer = Layer.text("ID: \(self.note.id.uuidString)", color: BeamColor.Generic.text.nsColor, size: 12)
        addLayer(ButtonLayer("noteIdBtn", noteIdLayer, activated: { [unowned self] in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(self.note.id.uuidString, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["noteIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 30))

        let databaseIdLayer = Layer.text("Database ID: \(nodeDatabaseId)", color: databaseTextColor, size: 12)
        addLayer(ButtonLayer("noteDatabaseIdBtn", databaseIdLayer, activated: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(nodeDatabaseId, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["noteDatabaseIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 50))

        let defaultDatabaseIdLayer = Layer.text("Default Database ID: \(defaultDatabaseId)", color: databaseTextColor, size: 12)
        addLayer(ButtonLayer("defaultDatabaseIdBtn", defaultDatabaseIdLayer, activated: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(defaultDatabaseId, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["defaultDatabaseIdBtn"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 70))

        let previousChecksumIdLayer = Layer.text("Previous Checksum: \(previousChecksum)", color: BeamColor.Generic.text.nsColor, size: 12)
        addLayer(ButtonLayer("previousChecksum", previousChecksumIdLayer, activated: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(previousChecksum, forType: .string)
        }, hovered: { [unowned self] hovered in
            self.layers["previousChecksum"]?.layer.backgroundColor = hovered ? BeamColor.Generic.textSelection.cgColor : NSColor.clear.cgColor
        }), origin: CGPoint(x: 0, y: 90))
    }

    public func setupContinueWidget(with notes: [BeamNote], and link: Link?) {
        let hasNotes = !notes.isEmpty
        let notesStr: String = notes.map({ $0.title }).joined(separator: " ")
        let continueNotesLayer = Layer.text(named: "continueNotes", "Continue to Notes: \(notesStr)", color: BeamColor.Generic.text.nsColor, size: 12)
        if hasNotes {
            addLayer(continueNotesLayer, origin: CGPoint(x: 0, y: 110))
        }

        if let linkTitle = link?.title, let linkUrl = link?.url {
            let continueLinksLayer = Layer.text(named: "continueLinks", "Continue to Link: \(linkTitle) \(linkUrl)", color: BeamColor.Generic.text.nsColor, size: 12)
            addLayer(continueLinksLayer, origin: CGPoint(x: 0, y: hasNotes ? 130 : 110))
        }
    }

    override func updateSubLayersLayout() {
        super.updateSubLayersLayout()

        CATransaction.disableAnimations {
            separatorLayer.frame = CGRect(x: 0, y: textLayer.frame.maxY + 4, width: 560, height: 1)
        }
    }
}
