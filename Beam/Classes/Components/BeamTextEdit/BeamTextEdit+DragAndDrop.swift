//
//  BeamTextEdit+DragAndDrop.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 14/10/2022.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    struct DragResult: Equatable {
        let element: ElementNode
        let shouldBeAfter: Bool
        let shouldBeChild: Bool

        func onlyDiffersByIndentation(from otherResult: DragResult) -> Bool {
            return self.element == otherResult.element && self.shouldBeAfter == otherResult.shouldBeAfter && self.shouldBeChild != otherResult.shouldBeChild
        }
    }
    private typealias EditorDragSessionNodes = (draggedNode: ElementNode, allNodes: [ElementNode])

    /// Updates the drag indicator for the desired cursor position
    /// - Parameter point: The position of the cursor
    /// - Returns: A DragResult with the hovered ElementNode, a bool if we should add the dragged element after this node and
    /// another bool if we should make the element a child or a sibbling
    @discardableResult private func updateDragIndicator(at point: CGPoint?) -> DragResult? {
        guard let rootNode = rootNode else { return nil }
        guard let point = point,
              let node = rootNode.widgetAt(point: CGPoint(x: point.x, y: point.y - rootNode.frame.minY)) as? ElementNode else {
            dragIndicator.isHidden = true
            previousDragResult = nil
            return nil
        }

        if dragIndicator.superlayer == nil {
            layer?.addSublayer(dragIndicator)
        }

        dragIndicator.backgroundColor = BeamColor.Bluetiful.cgColor
        dragIndicator.borderWidth = 0
        dragIndicator.isHidden = false
        dragIndicator.zPosition = 10
        dragIndicator.cornerRadius = 1
        dragIndicator.opacity = 0.5

        // Should the dragged element be after or before the hovered widget?
        let shouldBeAfter: Bool
        if point.y < (node.offsetInDocument.y + node.contentsFrame.height / 2) {
            shouldBeAfter = false
        } else {
            shouldBeAfter = true
        }

        let yPos = shouldBeAfter ? node.offsetInDocument.y + node.contentsFrame.maxY : node.offsetInDocument.y + node.contentsFrame.minY
        var initialFrame = CGRect(x: node.offsetInDocument.x + node.contentsLead, y: yPos, width: node.frame.width - node.contentsLead, height: 2)

        // Should the dragged element be a child or a sibbling?
        let beginningOfContentInNode = node.contentsFrame.minX + node.offsetInDocument.x
        let makeChildOffset = beginningOfContentInNode + node.childInset
        let shouldBeChild: Bool
        if (point.x - beginningOfContentInNode) > node.childInset && shouldBeAfter {
            shouldBeChild = true
            CATransaction.disableAnimations {
                initialFrame.origin.x = makeChildOffset
                initialFrame.size.width -= node.childInset
                dragIndicator.frame = initialFrame
            }
        } else {
            shouldBeChild = false
            CATransaction.disableAnimations {
                dragIndicator.frame = initialFrame
            }
        }

        let result = DragResult(element: node, shouldBeAfter: shouldBeAfter, shouldBeChild: shouldBeChild)
        performHapticFeedback(for: result)
        previousDragResult = result
        return result
    }

    private func performHapticFeedback(for dragResult: DragResult) {
        guard dragResult != previousDragResult, PreferencesManager.isHapticFeedbackOn else { return }
        let performer = NSHapticFeedbackManager.defaultPerformer
        if let previousDragResult = previousDragResult, previousDragResult.onlyDiffersByIndentation(from: dragResult) {
            performer.perform(.levelChange, performanceTime: .drawCompleted)
        } else {
            performer.perform(.alignment, performanceTime: .drawCompleted)
        }
    }

    //MARK: - NSDraggingDestination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if NSImage.canInit(with: sender.draggingPasteboard) {
            updateDragIndicator(at: convert(sender.draggingLocation))
            return .copy
        } else if sender.draggingPasteboard.canReadObject(forClasses: [BeamNoteDataHolder.self]) {
            updateDragIndicator(at: convert(sender.draggingLocation))
            return .move
        } else if sender.draggingPasteboard.canReadObject(forClasses: supportedPasteObjects, options: nil) {
            updateDragIndicator(at: convert(sender.draggingLocation))
            return .copy
        }
        else {
            return NSDragOperation()
        }
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        // This is an internal drag
        if let draggingSession = state?.data.currentDraggingSession,
            let draggedNodes = draggingSession.draggedObject as? EditorDragSessionNodes {
            if canDrop(draggedNodes.draggedNode, at: point) {
                updateDragIndicator(at: point)
            }
            let shouldCopy = NSApp.currentEvent?.modifierFlags.contains(.option) == true
            return shouldCopy ? .copy : .move
        } else {
        //This is an external drag
            updateDragIndicator(at: point)
            return .copy
        }
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        updateDragIndicator(at: nil)
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        updateDragIndicator(at: nil)
    }

    static let maximumImageSize = 40*1024*1024

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let rootNode = rootNode
            else { return false }
        defer {
            updateDragIndicator(at: nil)
        }
        guard let dragResult = updateDragIndicator(at: convert(sender.draggingLocation)) else {
            return false
        }

        let newParent: ElementNode = dragResult.shouldBeAfter && dragResult.shouldBeChild ? dragResult.element : dragResult.element.parent as? ElementNode ?? rootNode
        let afterNode: ElementNode? = dragResult.shouldBeAfter ? dragResult.element : dragResult.element.previousSibbling() as? ElementNode

        guard let pastedElements = sender.draggingPasteboard.readObjects(forClasses: supportedPasteObjects, options: nil)
        else {
            Logger.shared.logError("Unable to get files from drag operation", category: .noteEditor)
            return false
        }

        var received: Set<Bool> = []
        for element in pastedElements.reversed() {
            if let url = element as? URL, url.isFileURL,
               let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                // We only handle image files
                received.insert(insertImageNode(with: image, name: url.lastPathComponent, rootNode: rootNode, newParent: newParent, afterNode: afterNode))
            } else if let text = element as? NSAttributedString {
                received.insert(handleTextDrag(text, rootNode: rootNode, newParent: newParent, afterNode: afterNode))
            } else if let image = element as? NSImage {
                received.insert(insertImageNode(with: image, name: nil, rootNode: rootNode, newParent: newParent, afterNode: afterNode))
            } else if let noteHolder = element as? BeamNoteDataHolder {
                received.insert(handleNodeDrag(holder: noteHolder, rootNode: rootNode, newParent: newParent, afterNode: afterNode, dragResult: dragResult))
            }
        }
        return received.contains(true)
    }

    //MARK: - Handle dragged objects
    private func handleNodeDrag(holder: BeamNoteDataHolder, rootNode: TextRoot, newParent: ElementNode, afterNode: ElementNode?, dragResult: DragResult) -> Bool {

        // If we drag in the same editor, we use the move in editor logic
        if let draggingSession = state?.data.currentDraggingSession,
           let originalEditor = draggingSession.draggingSource as? BeamTextEdit,
           originalEditor.note == self.note,
           let draggedNodes = draggingSession.draggedObject as? EditorDragSessionNodes {
            move(node: draggedNodes.draggedNode, with: dragResult, in: rootNode)
            return false
        } else {
            // Else, we are not moving in the same editor, we can use the classical
            do {
                let decodedNote = try BeamJSONDecoder().decode(BeamNote.self, from: holder.noteData)
                for element in decodedNote.children.reversed() {
                    guard let newElement = element.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) else {
                        Logger.shared.logError("Paste error, unable to copy \(element)", category: .noteEditor)
                        return false
                    }
                    element.updateNoteNamesInInternalLinks(recursive: true)

                    if case .image(let id, _, _) = element.kind {
                        importImageIfNeeded(id: id, elementHolder: holder)
                    }
                    rootNode.cmdManager.insertElement(newElement, inNode: newParent, afterNode: afterNode)
                }
            } catch {
                return false
            }
            return true
        }
    }

    private func handleTextDrag(_ text: NSAttributedString, rootNode: ElementNode, newParent: ElementNode, afterNode: ElementNode?) -> Bool {
        let bullets = text.split(separateBy: "\n")
        for bullet in bullets.reversed() {
            let newElement = BeamElement(BeamText(attributedString: bullet))
            rootNode.cmdManager.insertElement(newElement, inNode: newParent, afterNode: afterNode)
            Logger.shared.logInfo("Added Bullet to note \(String(describing: rootNode.element.note))", category: .noteEditor)
        }
        return true
    }

    private func insertImageNode(with image: NSImage, name: String?, rootNode: ElementNode, newParent: ElementNode, afterNode: ElementNode?) -> Bool {
        guard let fileManager = self.data?.fileDBManager else { return false }

        guard let data = image.jpegRepresentation else {
            Logger.shared.logError("Error while getting jpeg representation from NSImage", category: .noteEditor)
            return false
        }
        if data.count > Self.maximumImageSize {
            UserAlert.showError(message: "This image is too large for beam.", informativeText: "Please use images that are smaller than 40MB.", buttonTitle: "Cancel")
            return false
        }

        do {
            let uid = try fileManager.insert(name: name ?? "Dragged Image \(UUID())", data: data)
            let newElement = BeamElement()
            newElement.kind = .image(uid, displayInfos: MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width), displayRatio: nil))
            rootNode.cmdManager.insertElement(newElement, inNode: newParent, afterNode: afterNode)
            try fileManager.addReference(fromNote: rootNode.elementId, element: newElement.id, to: uid)
            Logger.shared.logInfo("Added Image to note \(String(describing: rootNode.element.note)) with uid \(uid) from dropped file (\(image))", category: .noteEditor)
        } catch {
            Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
            return false
        }
        return true
    }
    
    // MARK: - Reordering bullet

    func widgetDidStartMoving(_ widget: Widget, at point: CGPoint) -> Bool {
        guard canMove(widget) else { return false }
        guard let movedNode = widget as? ElementNode else { return false }

        let selectedNodesToMove = selectedNodesToMoveAlong(for: movedNode)
        for node in selectedNodesToMove {
            node.isDraggedForMove = true
        }
        focusedWidget = nil
        mouseMoveOrigin = point
        widget.isDraggedForMove = true
        return true
    }

    func widgetDidStopMoving(_ widget: Widget, at point: CGPoint) {

        defer {
            cleanupAfterDraggingWidget(widget)
        }

        let dragResult: DragResult?

        let canDrop = canDrop(widget, at: point)
        if !canDrop, let previous = previousDragResult {
            dragResult = previous
        } else if canDrop {
            dragResult = updateDragIndicator(at: point)
        } else {
            return
        }

        guard let dragResult = dragResult, let rootNode = rootNode else { return }
        guard let movedNode = widget as? ElementNode else { return }

        move(node: movedNode, with: dragResult, in: rootNode)
    }

    func widgetMoved(_ widget: Widget, at point: CGPoint) {
        guard let mouseMoveOrigin = self.mouseMoveOrigin else { return }
        guard let movedNode = widget as? ElementNode else { return }

        let isOutOfView = shouldTriggerExternalDrag(point: point, widget: widget)
        if canDrop(widget, at: point) {
            updateDragIndicator(at: isOutOfView ? nil : point)
        } else if isOutOfView {
            performExternalDrag(for: movedNode, at: point)
        }

        let offset = CGPoint(x: point.x - mouseMoveOrigin.x, y: point.y -  mouseMoveOrigin.y)
        widget.translateForMove(offset, outOfEditor: isOutOfView)
        let selectedNodesToMove = selectedNodesToMoveAlong(for: movedNode)
        for node in selectedNodesToMove {
            node.translateForMove(offset, outOfEditor: isOutOfView)
        }
    }

    /// Creates an external drag session for the moved ElementNode
    /// - Parameters:
    ///   - movedNode: The node currently moved
    ///   - point: The position of the node
    private func performExternalDrag(for movedNode: ElementNode, at point: CGPoint) {
        guard state?.data.currentDraggingSession == nil else { return }

        if PreferencesManager.isHapticFeedbackOn {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.alignment, performanceTime: .default)
        }

        // We need to grab all dragged elements (including those selected), with their children
        var allMovedNodes = sortedSelectedRootsToMoveAlong(for: movedNode)
        if allMovedNodes.isEmpty {
            allMovedNodes = [movedNode]
        }
        let movedElements = allMovedNodes.flatMap { (node: ElementNode) -> [BeamElement] in
            var all: [BeamElement] = [node.element]
            all.append(contentsOf: node.element.flatElements)
            return all
        }

        if let note = rootNode?.note, let clonedNote: BeamNote = note.deepCopy(withNewId: false, selectedElements: movedElements, includeFoldedChildren: true) {
            let data = try? JSONEncoder().encode(clonedNote)

            if let noteData = data, !noteData.isEmpty {
                let elementHolder = BeamNoteDataHolder(noteData: noteData, includedImages: [:])
                let draggedItem = NSDraggingItem(pasteboardWriter: elementHolder)
                draggedItem.draggingFrame = frame
                draggedItem.imageComponentsProvider = {
                    var array: [NSDraggingImageComponent] = []
                    for node in allMovedNodes {
                        let component = NSDraggingImageComponent(key: .icon)
                        let layer = node.layer
                        let op = layer.opacity
                        layer.opacity = 1
                        let image = layer.image()?.flipHorizontally()
                        layer.opacity = op
                        component.frame = CGRect(origin: point, size: layer.bounds.size)
                        component.contents = image
                        array.append(component)
                    }
                    return array
                }
                state?.data.currentDraggingSession = ExternalDraggingSession(draggedObject: (movedNode, allMovedNodes), draggingSource: self, draggingItem: draggedItem)
                DispatchQueue.main.async { [self] in
                    let session = beginDraggingSession(with: [draggedItem], event: NSApp.currentEvent!, source: self)
                    session.animatesToStartingPositionsOnCancelOrFail = false
                    state?.data.currentDraggingSession?.draggingSession = session
                }
            }
        } else {
            Logger.shared.logError("Copy error, unable to copy \(note)", category: .noteEditor)
        }
    }

    private func canMove(_ widget: Widget) -> Bool {
        guard widget as? ProxyNode == nil else { return false }
        return true
    }

    private func canDrop(_ widget: Widget, at point: NSPoint) -> Bool {
        guard let rootNode = rootNode else { return false }
        guard let movedNode = widget as? ElementNode else { return false }

        if let node = rootNode.widgetAt(point: CGPoint(x: point.x, y: point.y - rootNode.frame.minY)) as? ElementNode {
            return canDrop(movedNode, on: node)
        }
        return false
    }

    private func canDrop(_ movedNode: ElementNode, on destinationNode: ElementNode) -> Bool {
        if !(destinationNode is ProxyNode), destinationNode.elementKind != .dailySummary,
           destinationNode.elementId != movedNode.elementId,
           !movedNode.allChildren.compactMap({ ($0 as? ElementNode)?.elementId }).contains(destinationNode.elementId),
           !destinationNode.allParents.compactMap({ ($0 as? ElementNode)?.elementId }).contains(movedNode.elementId),
           !selectedNodesToMoveAlong(for: movedNode).map({ $0.elementId }).contains(destinationNode.elementId) {
            return true
        }
        return false
    }

    private func shouldTriggerExternalDrag(point: CGPoint, widget: Widget) -> Bool {
        let middleWidgetPoint = CGPoint(x: point.x + widget.frame.width / 2, y: point.y)
        return !frame.contains(point) || !frame.contains(middleWidgetPoint)
    }

    private func cleanupAfterDraggingWidget(_ widget: Widget) {
        guard let movedNode = widget as? ElementNode else { return }
        widget.isDraggedForMove = false
        mouseMoveOrigin = nil
        updateDragIndicator(at: nil)

        for node in selectedNodesToMoveAlong(for: movedNode) {
            node.isDraggedForMove = false
        }
    }

    private func selectedNodesToMoveAlong(for initialNode: ElementNode) -> Set<ElementNode> {
        if let nodes = rootNode?.state.nodeSelection?.nodes, nodes.contains(initialNode) {
            return nodes
        } else {
            return []
        }
    }

    private func sortedSelectedRootsToMoveAlong(for initialNode: ElementNode) -> [ElementNode] {
        if let nodes = rootNode?.state.nodeSelection?.sortedRoots, nodes.contains(initialNode) {
            return nodes
        } else {
            return []
        }
    }

    private func isMovedNodeSibbling(_ movedNode: ElementNode, andBefore destinationNode: ElementNode) -> Bool {

        guard let movedParent = movedNode.parent as? ElementNode, let destinationNodeParent = destinationNode.parent as? ElementNode else { return false }
        if movedParent.elementId == destinationNodeParent.elementId,
           let destinationIndex = destinationNode.indexInParent,
            let movedElementIndex = movedNode.indexInParent,
            destinationIndex > movedElementIndex {
            return true
        }
        return false
    }

    private func move(node movedNode: ElementNode, with dragResult: DragResult, in rootNode: TextRoot) {
        let newParent: ElementNode
        var index: Int
        let destinationElementIndex = dragResult.element.indexInParent ?? 0
        let selectedNodes = sortedSelectedRootsToMoveAlong(for: movedNode)

        if dragResult.shouldBeAfter && dragResult.shouldBeChild {
            newParent = dragResult.element
            index = 0
        } else {
            var previousNodeMovingOffset = 0
            // If the moving node is a sibbling of the destination, and is located before, we need to offet by one
            if isMovedNodeSibbling(movedNode, andBefore: dragResult.element) {
                previousNodeMovingOffset = 1
            }
            index = destinationElementIndex + (dragResult.shouldBeAfter ? 1 : 0) - previousNodeMovingOffset
            if movedNode.elementId == dragResult.element.elementId {
                index -= 1
            }
            newParent = dragResult.element.parent as? ElementNode ?? rootNode
        }

        // Make extra sure we don't try to reparent an element with itself
        guard canDrop(movedNode, on: newParent) else {
            return
        }

        if !selectedNodes.isEmpty {
            var offset = 0
            rootNode.cmdManager.beginGroup(with: "Move Multiple Elements")
            let shouldIncreaseIndex = !isMovedNodeSibbling(selectedNodes.first ?? movedNode, andBefore: dragResult.element) || dragResult.shouldBeChild
            for node in selectedNodes {
                if shouldIncreaseIndex {
                    offset += 1
                }
                rootNode.cmdManager.reparentElement(node, to: newParent, atIndex: index + offset)
            }
            rootNode.cmdManager.endGroup()
        } else {
            rootNode.cmdManager.reparentElement(movedNode, to: newParent, atIndex: index)
        }
    }

}

extension BeamTextEdit: ExternalDraggingSource {

    public func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) { }

    public func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) { }

    public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {

        defer {
            state?.data.currentDraggingSession = nil
        }

        guard let draggedElements = state?.data.currentDraggingSession?.draggedObject as? EditorDragSessionNodes else { return }
        let cmdManager = rootNode?.cmdManager
        let allMovedNodes = draggedElements.allNodes
        if operation.contains(.move) {
            cmdManager?.beginGroup(with: "Delete moved nodes from source")
            for node in allMovedNodes {
                cmdManager?.deleteElement(for: node)
            }
            cmdManager?.endGroup()
        }

        for object in allMovedNodes {
            cleanupAfterDraggingWidget(object)
        }
    }

    func endDraggingItem() {

    }

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return .copy
        case .withinApplication:
            return [.move, .copy]
        @unknown default:
            return .copy
        }
    }
}
