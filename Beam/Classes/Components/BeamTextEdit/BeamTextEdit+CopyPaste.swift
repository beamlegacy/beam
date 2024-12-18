//
//  BeamTextEdit+CopyPaste.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/04/2021.
//

import Foundation
import BeamCore
import UniformTypeIdentifiers

extension BeamTextEdit {
    // Disable detection during copy / paste
    private func disableInputDetector() {
        inputDetectorState -= 1
    }

    // Enable detection
    private func enableInputDetector() {
        inputDetectorState += 1
    }

    func buildStringFrom(image source: UUID) -> NSAttributedString {
        guard let imageRecord = try? data?.fileDBManager?.fetch(uid: source)
        else {
            Logger.shared.logError("ImageNode unable to fetch image '\(source)' from FileDB", category: .noteEditor)
            return NSAttributedString()
        }

        guard let image = NSImage(data: imageRecord.data)
        else {
            Logger.shared.logError("ImageNode unable to decode image '\(source)' from FileDB", category: .noteEditor)
            return NSAttributedString()
        }

        let attachment: NSTextAttachment = NSTextAttachment()
        attachment.image = image
        let attrString: NSAttributedString = NSAttributedString(attachment: attachment)
        return attrString
    }

    func buildStringFrom(node: ElementNode) -> NSAttributedString {
        let strNode = NSMutableAttributedString()
        strNode.append(NSAttributedString(string: String.tabs(max(0, node.element.depth - 1)) + String.bullet() + String.spaces(1)))

        switch node.elementKind {
        case .bullet, .heading, .quote, .check, .blockReference, .code, .dailySummary, .tabGroup:
            let config = BeamTextAttributedStringBuilder.Config(elementKind: node.elementKind,
                                                                ranges: node.elementText.ranges,
                                                                fontSize: TextNode.fontSizeFor(kind: node.elementKind),
                                                                fontColor: node.color,
                                                                caret: nil,
                                                                markedRange: .none,
                                                                selectedRange: .none,
                                                                searchedRanges: [],
                                                                mouseInteraction: nil)
            let builder = BeamTextAttributedStringBuilder()
            strNode.append(builder.build(config: config))

        case .divider:
            strNode.append(NSAttributedString(string: "\n---\n"))

        case let .image(id, _, _):
            strNode.append(buildStringFrom(image: id))

        case .embed(let url, let source, _):
            strNode.append(NSAttributedString(string: source?.title ?? url.absoluteString, attributes: [.link: url]))
        }

        return strNode
    }

    func buildStringFrom(nodes: [ElementNode]) -> NSAttributedString {
        let strNodes = NSMutableAttributedString()
        for node in nodes {
            guard (node as? TextRoot) == nil else { continue }
            if nodes.count > 1 {
                strNodes.append(buildStringFrom(node: node))
                strNodes.append(NSAttributedString(string: "\n"))
            } else {
                strNodes.append(buildStringFrom(node: node))
            }
        }
        return strNodes
    }

    // MARK: - Cut
    @IBAction func cut(_ sender: Any) {
        guard let rootNode = rootNode else { return }
        setPasteboard()
        if let nodes = rootNode.state.nodeSelection?.sortedNodes, !nodes.isEmpty {
            rootNode.eraseNodeSelection(createEmptyNodeInPlace: nodes.count == rootNode.element.children.count)
        } else {
            guard let node = rootNode.focusedWidget as? TextNode else { return }
            node.cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
        }
    }

    // MARK: - Copy
    @IBAction func copy(_ sender: Any) {
        setPasteboard()
    }

    private func setPasteboard() {
        guard let rootNode = rootNode else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let strNodes = NSMutableAttributedString()
        var beamText: BeamText?
        var noteData: Data?

        /// This is the UUID/BeamFileRecord association that will be used when copying multiple nodes into a BeamNoteDataHolder
        /// The data will be used when copy and pasting between two beam instances to preserve images
        var images: [UUID: BeamFileRecord] = [:]

        /// Raw images will be used if we only copy ImageNodes, to put only the images inside the pasteboard
        var rawImages: [NSImage] = []

        if  let note = rootNode.note,
            let sortedNodes = rootNode.state.nodeSelection?.sortedNodes, !sortedNodes.isEmpty {
            var sortedSelectedElements: [BeamElement] = []
            sortedNodes.forEach { (node) in
                sortedSelectedElements.append(node.element)
                if case .image(let id, _, _) = node.element.kind {
                    guard let imageRecord = try? data?.fileDBManager?.fetch(uid: id), let image = NSImage(data: imageRecord.data) else { return }
                    images[id] = imageRecord
                    rawImages.append(image)
                }
            }

            // We only copied images, so let's just use put raw images in the pasteboard
            if sortedNodes.count == rawImages.count {
                pasteboard.writeObjects(rawImages)
                return
            }

            guard let clonedNote: BeamNote = note.deepCopy(withNewId: false, selectedElements: sortedSelectedElements, includeFoldedChildren: true) else {
                Logger.shared.logError("Copy error, unable to copy \(note)", category: .noteEditor)
                return
            }

            do {
                noteData = try JSONEncoder().encode(clonedNote)
            } catch {
                Logger.shared.logError("Can't encode Cloned Note", category: .general)
            }
            strNodes.append(buildStringFrom(nodes: sortedNodes))
        } else {
            // We only selected partial text inside a TextNode.
            // We will copy the text as BeamText for beam paste destination, and prepare a NSAttributedString for non-beam paste destination
            if let node = focusedWidget as? TextNode {
                if let range = node.screenRange(for: selectedTextRange) {
                    let attributedString = node.attributedString.attributedSubstring(from: range)
                    strNodes.append(attributedString)
                }

                beamText = node.element.text.extract(range: selectedTextRange)
            }
        }

        do {
            if let noteData = noteData, !noteData.isEmpty {
                let elementHolder = BeamNoteDataHolder(noteData: noteData, includedImages: images)
                let elementHolderData = try PropertyListEncoder().encode(elementHolder)
                pasteboard.addTypes([.noteDataHolder], owner: nil)
                pasteboard.setData(elementHolderData, forType: .noteDataHolder)
            }
            if let bText = beamText, !bText.isEmpty {
                let bTextHolder = BeamTextHolder(bText: bText)
                let beamTextData = try PropertyListEncoder().encode(bTextHolder)
                pasteboard.addTypes([.bTextHolder], owner: nil)
                pasteboard.setData(beamTextData, forType: .bTextHolder)
            }

            // If we prepared a NSAttributedString, we create a rtf or rtfd (if we have images) document in the pastebaord for non-beam paste destination
            if strNodes.length > 0 {
                // Added this to clean lineSpacing, while lineSpacing in TextNode is not working
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 0
                strNodes.addAttribute(.paragraphStyle, value: style, range: strNodes.wholeRange)
                let docAttrRtf: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: rawImages.isEmpty ? NSAttributedString.DocumentType.rtf : NSAttributedString.DocumentType.rtfd, .characterEncoding: String.Encoding.utf8]
                let rtfData = try strNodes.data(from: NSRange(location: 0, length: strNodes.length), documentAttributes: docAttrRtf)

                pasteboard.setData(rtfData, forType: rawImages.isEmpty ? .rtf : .rtfd )
                pasteboard.setString(strNodes.string, forType: .string)
            }
        } catch {
            Logger.shared.logError("Error when encoding content for the pasteboard", category: .general)
        }
    }

    // MARK: - Paste
    @IBAction func paste(_ sender: Any) {
        disableAnimationAtNextLayout()
        if NSPasteboard.general.canReadObject(forClasses: supportedPasteObjects, options: nil) {
            let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteObjects, options: nil)

            if focusedWidget is CodeNode {
                guard let firstObject = objects?.first else { return }
                if let bTextHolder: BeamTextHolder = objects?.first as? BeamTextHolder {
                    paste(beamTextHolder: bTextHolder, fromRawPaste: true)
                } else if let fileURL = objects?.first as? NSURL {
                    if let string = fileURL.absoluteString {
                        let attrString = NSAttributedString(string: string)
                        paste(attributedStrings: [attrString], fromRawPaste: true)
                    }
                } else if let string = (firstObject as? NSAttributedString)?.string ?? (firstObject as? String) {
                    let attrString = NSAttributedString(string: removeExtraneousIndentation(string))
                    paste(attributedStrings: [attrString], fromRawPaste: true)
                }
                return
            }

            if let elementHolder: BeamNoteDataHolder = objects?.first as? BeamNoteDataHolder {
                paste(elementHolder: elementHolder)
            } else if let bTextHolder: BeamTextHolder = objects?.first as? BeamTextHolder {
                paste(beamTextHolder: bTextHolder)
            } else if let image = objects?.first as? NSImage {
                paste(image: image)
            } else if let fileUrl = objects?.first as? NSURL {
                paste(url: fileUrl as URL)
            } else if let attributedStr = objects?.first as? NSAttributedString {
                paste(attributedStrings: attributedStr.split(separateBy: "\n"))
            } else if let pastedStr: String = objects?.first as? String {
                var lines = [NSAttributedString]()
                pastedStr.enumerateLines { line, _ in
                    lines.append(NSAttributedString(string: line))
                }
                paste(attributedStrings: lines)
            }
        }
    }

    private func removeExtraneousIndentation(_ string: String) -> String {
        var prefix: String? = nil

        string.enumerateLines { line, stop in
            if line.isEmpty {
                return
            }

            let scanner = Scanner(string: line)
            scanner.charactersToBeSkipped = nil

            guard let string = scanner.scanCharacters(from: .whitespaces) else {
                prefix = nil
                stop = true
                return
            }

            if let previousPrefix = prefix {
                if string.count < previousPrefix.count {
                    if !previousPrefix.hasPrefix(string) {
                        prefix = nil
                        stop = true
                        return
                    }
                    prefix = string
                } else {
                    if !string.hasPrefix(previousPrefix) {
                        prefix = nil
                        stop = true
                        return
                    }
                }
            } else {
                prefix = string
            }
        }

        guard let prefix = prefix else {
            return string
        }

        var lines: [String] = []

        string.enumerateLines { line, _ in
            if line.isEmpty {
                lines.append("")
            } else {
                lines.append(String(line.dropFirst(prefix.count)))
            }
        }

        return lines.joined(separator: "\n")
    }

    private func paste(beamTextHolder: BeamTextHolder, fromRawPaste: Bool = false) {
        let bText = beamTextHolder.bText.resolvedNotesNames() ?? beamTextHolder.bText
        if fromRawPaste {
            rootNode?.insertText(string: beamTextHolder.bText.text, replacementRange: nil)
        } else {
            rootNode?.insertText(text: bText, replacementRange: nil)
        }
    }

    @objc func pasteAsPlainText(_ sender: Any) {
        guard NSPasteboard.general.canReadObject(forClasses: supportedPasteAsPlainTextObjects, options: nil) else {
            return
        }
        disableAnimationAtNextLayout()
        let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteAsPlainTextObjects, options: nil)
        if let bTextHolder: BeamTextHolder = objects?.first as? BeamTextHolder {
            paste(beamTextHolder: bTextHolder, fromRawPaste: true)
        } else if let attributedStr = objects?.first as? NSAttributedString {
            paste(attributedStrings: attributedStr.split(separateBy: "\n"), fromRawPaste: true)
        } else if let pastedStr: String = objects?.first as? String {
            let attributedStrings = pastedStr.split(whereSeparator: \.isNewline).map { NSAttributedString(string: String($0)) }
            paste(attributedStrings: attributedStrings, fromRawPaste: true)
        }
    }

    private func paste(elementHolder: BeamNoteDataHolder) {
        guard let rootNode = rootNode else { return }
        do {
            guard let mngrNode = focusedWidget else {
                Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
                return
            }

            let cmdManager = mngrNode.cmdManager
            cmdManager.beginGroup(with: "Paste Element")
            defer { cmdManager.endGroup() }

            if rootNode.state.nodeSelection != nil {
                rootNode.eraseNodeSelection(createEmptyNodeInPlace: true, createNodeInEmptyParent: false)
            } else if !rootNode.state.selectedTextRange.isEmpty {
                guard let node = focusedWidget as? TextNode else { return }
                node.cmdManager.deleteText(in: node, for: rootNode.rangeToDeleteText(in: node, cursorAt: rootNode.cursorPosition, forward: false))
            }
            guard let firstNode = focusedWidget as? TextNode else { return }
            let previousBullet = firstNode.element

            guard let node = focusedWidget as? ElementNode,
                  let parent = node.parent as? ElementNode else {
                Logger.shared.logError("Can't paste on a node that is not an element node", category: .noteEditor)
                return
            }

            let decodedNote = try BeamJSONDecoder().decode(BeamNote.self, from: elementHolder.noteData)
            for element in decodedNote.children {
                guard let newElement = element.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) else {
                    Logger.shared.logError("Paste error, unable to copy \(element)", category: .noteEditor)
                    return
                }
                element.updateNoteNamesInInternalLinks(recursive: true)
                guard let node = focusedWidget as? ElementNode else {
                    return
                }

                if case .image(let id, _, _) = element.kind {
                    importImageIfNeeded(id: id, elementHolder: elementHolder)
                }

                node.cmdManager.insertElement(newElement, inNode: parent, afterElement: node.element)
                node.cmdManager.focus(newElement, in: node)
            }
            if previousBullet.children.isEmpty, previousBullet.text.isEmpty {
                node.cmdManager.deleteElement(for: previousBullet, context: mngrNode)
            }
        } catch {
            Logger.shared.logError("Can't encode Cloned Note", category: .general)
        }
    }

    func importImageIfNeeded(id: UUID, elementHolder: BeamNoteDataHolder) {
        let existingFileRecord = try? data?.fileDBManager?.fetch(uid: id)
        guard let fileRecord = elementHolder.imageData[id], existingFileRecord == nil else { return }
        try? data?.fileDBManager?.insert(files: [fileRecord])
    }

    private func paste(url: URL) {
        guard let type = UTType(tag: url.pathExtension.lowercased(), tagClass: .filenameExtension, conformingTo: nil),
              type.isSubtype(of: .image),
              let image = NSImage(contentsOf: url) else {
                  Logger.shared.logError("Unable to load image from url \(url)", category: .noteEditor)

                  // paste the URL as text
                  let attributedStr = NSAttributedString(string: url.absoluteString, attributes: [.link: url])
                  paste(attributedStrings: [attributedStr])

                  return
              }
        paste(image: image, with: url.lastPathComponent)
    }

    private func paste(image: NSImage, with name: String? = nil) {
        guard let node = focusedWidget as? ElementNode,
              let parent = node.parent as? ElementNode,
              let fileManager = data?.fileDBManager
        else {
            Logger.shared.logError("Can't paste on a node that is not an element node", category: .noteEditor)
            return
        }

        guard let jpegImageData = image.jpegRepresentation else {
            Logger.shared.logError("Error while trying to get jpeg representation from an NSImage", category: .noteEditor)
            return
        }

        if jpegImageData.count > Self.maximumImageSize {
            UserAlert.showError(message: "This image is too large for beam.", informativeText: "Please use images that are smaller than 40MB.", buttonTitle: "Cancel")
            return
        }

        do {
            let cmdManager = node.cmdManager
            cmdManager.beginGroup(with: "Paste Image")
            defer { cmdManager.endGroup() }

            if rootNode?.state.nodeSelection != nil {
                rootNode?.eraseNodeSelection(createEmptyNodeInPlace: false, createNodeInEmptyParent: false)
            }

            let uid = try fileManager.insert(name: name ?? "image\(UUID())", data: jpegImageData)
            let newElement = BeamElement()
            newElement.kind = .image(uid, displayInfos: MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width), displayRatio: nil))
            cmdManager.insertElement(newElement, inNode: parent, afterNode: node)
            if node.element.kind.isText && node.elementText.isEmpty {
                cmdManager.deleteElement(for: node)
            }
            try fileManager.addReference(fromNote: note.id, element: newElement.id, to: uid)
            cmdManager.focus(newElement, in: parent, leading: false)
            Logger.shared.logInfo("Added Image to note \(String(describing: note)) with uid \(uid) from pasted file (\(image))", category: .noteEditor)
        } catch {
            Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
        }
    }

    private func paste(attributedStrings: [NSAttributedString], fromRawPaste: Bool = false) {
        guard let rootNode = rootNode else { return }
        guard let mngrNode = focusedWidget else {
            Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
            return
        }
        let cmdManager = mngrNode.cmdManager
        cmdManager.beginGroup(with: "Paste Text")
        guard let node = focusedWidget as? TextNode else { return }
        var lastInserted: ElementNode? = node
        let parent = node.parent as? ElementNode ?? node
        var insertedElements: [BeamText] = []
        for (idx, attributedString) in attributedStrings.enumerated() {
            guard !attributedString.string.isEmpty else { continue }
            let cleanedText = attributedString.clean(with: "\\s\u{2022}\\s", in: NSRange(0..<3))
            let beamText: BeamText
            if fromRawPaste {
                beamText = BeamText(cleanedText.string, attributes: rootNode.state.attributes)
            } else {
                beamText = BeamText(attributedString: cleanedText)
            }
            insertedElements.append(beamText)
            if idx == 0 {
                disableInputDetector()
                rootNode.insertText(text: beamText, replacementRange: selectedTextRange)
                enableInputDetector()
            } else {
                let element = BeamElement(beamText)
                parent.cmdManager.insertElement(element, inNode: parent, afterNode: lastInserted)
                parent.cmdManager.focus(element, in: node)
                lastInserted = focusedWidget as? ElementNode
            }
        }
        cmdManager.endGroup()

        guard !fromRawPaste else { return }

        guard let lastInsertedNode = lastInserted as? TextNode,
              insertedElements.count == 1, let lastInsertedElement = insertedElements.last  else { return }
        // let's find the newly inserted BeamText.Range using the cursor.
        let rangeAtCursor = lastInsertedNode.elementText.rangeAt(position: lastInsertedNode.cursorPosition)
        guard rangeAtCursor.string == lastInsertedElement.text, rangeAtCursor.attributes == lastInsertedElement.ranges.first?.attributes else { return }
        let embedable = showLinkEmbedPasteMenu(for: rangeAtCursor)
        if !embedable {
            updateLinkToFormattedLink(in: lastInsertedNode, at: rangeAtCursor, with: cmdManager)
        }
    }

    /// Updates a plain link to the formatted version of "<linktitle> - <source site>"
    /// To get the link title it will query the proxy API. The proxy API will attempt to trim
    /// a trailing the site name from the page title.
    /// - Parameters:
    ///   - node: Target node to update
    ///   - range: Range of node that contains the link
    ///   - cmdManager: CommandManager<Widget> to execute text edit events with
    public func updateLinkToFormattedLink(in node: TextNode, at range: BeamText.Range, with cmdManager: CommandManager<Widget>) {
        let urls: [String] = range.attributes.compactMap { attribute in
            guard case let .link(url) = attribute else { return nil }
            return url
        }
        guard urls.count == 1, let url = URL(string: urls.first ?? "") else { return }
        Task.detached(priority: .background) { @MainActor [weak self] in
            guard let self = self else { return }
            let fetchedTitle = await WebNoteController.convertURLToBeamTextLink(url: url)
            let cursorIsStillAtEndOfLink = self.rootNode?.cursorPosition == range.end
            let endRange = range.position + fetchedTitle.wholeRange.upperBound
            self.disableInputDetector()
            cmdManager.beginGroup(with: "UpdateLinkToFormattedLink")
            cmdManager.replaceText(in: node, for: range.range, with: fetchedTitle)
            cmdManager.insertText(BeamText(text: " ", attributes: []), in: node, at: endRange)
            if cursorIsStillAtEndOfLink {
                cmdManager.focusElement(node, cursorPosition: endRange + 1)
            }
            cmdManager.endGroup()
            self.enableInputDetector()
        }
    }
}
