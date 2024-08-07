//
//  BeamNote+Merge.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 17/02/2022.
//

import Foundation

public extension BeamNote {
    func merge(other: BeamNote, ancestor: BeamNote, advantageOther: Bool) -> BeamVersion.Comparison {
        if self.id == other.id {
            switch version.compare(with: other.version) {
            case .ancestor:
                Logger.shared.logWarning("BeamNote.merge \(self) and \(other) -> fast forward", category: .document)
                // We're an ancestor of other so we should forward ourself to it:
                self.updateWith(other)
                Self.resetHistory(self)
                return .ancestor
            case .descendant:
                Logger.shared.logWarning("BeamNote.merge \(self) and \(other) -> descendant (do nothing)", category: .document)
                // We're a direct descendant of other so we already have everything we need, bailout
                return .descendant
            case .equal:
                Logger.shared.logWarning("BeamNote.merge \(self) and \(other) -> equal (do nothing)", category: .document)
                // We're the same version so we already have everything we need, bailout
                return .equal
            case .conflict:
                Logger.shared.logWarning("BeamNote.merge \(self) and \(other) -> conflict, actual merge", category: .document)
            }
        }
        if self.id != other.id {
            Logger.shared.logWarning("BeamNote.merge \(self) and \(other) -> conflict or heterogen notes, merge", category: .document)
        }
        // Merge tombstones and remove elements that have been removed on any parts
        self.version = self.version.receive(other: other.version)
        let tombstones = self.tombstones.union(other.tombstones)

        var ancestorElems = [UUID: BeamElement]()
        for e in ancestor.flatElements {
            ancestorElems[e.id] = e
        }

        var elems = [UUID: BeamElement]()
        for e in flatElements {
            if tombstones.contains(e.id) {
                e.parent?.removeChild(e)
            } else {
                elems[e.id] = e
            }
        }

        var otherElems = [UUID: BeamElement]()
        for e in other.flatElements {
            if tombstones.contains(e.id) {
                e.parent?.removeChild(e)
            } else {
                otherElems[e.id] = e
            }
        }

        // Merge the tabGroups
        let allTabGroups = Set(tabGroups).union(Set(other.tabGroups))
        let tabGroupsByRemovingDeleted = allTabGroups.subtracting(tombstones)
        self.tabGroups = Array(tabGroupsByRemovingDeleted)

        self.tombstones = tombstones

        var placed = Set<UUID>()
        mergeChildren(other: other, alreadyPlaced: &placed, otherElements: otherElems)

        // Now update contents if needed:
        for element in flatElements {
            if let otherElement = otherElems[element.id] {
                if element.text == otherElement.text {
                    // Do nothing!
                } else {
                    if let ancestorElement = ancestorElems[element.id] {
                        element.text = element.text.merge(ancestor: ancestorElement.text, other: otherElement.text, strategy: .chooseTheirs) ?? element.text
                    } else {
                        element.text = element.text.merge(ancestor: element.text, other: otherElement.text, strategy: .chooseTheirs) ?? element.text
                    }
                }
                element.kind = otherElement.kind
                element.open = otherElement.open
                element.collapsed = otherElement.collapsed
                element.updateDate = otherElement.updateDate
                element.childrenFormat = otherElement.childrenFormat
            }
        }

        Self.resetHistory(self)

        return .conflict
    }

    func concatenate(other: BeamNote) {
        guard !other.isEntireNoteEmpty() else { return }
        for child in other.children {
            guard let newChild = child.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) else { continue }
            addChild(newChild)
        }
    }
}

fileprivate extension BeamElement {
    func mergeChildren(other: BeamElement, alreadyPlaced: inout Set<UUID>, otherElements: [UUID: BeamElement]) {

        var index = 0
        var otherIndex = 0

        var newChildren = [BeamElement]()

        let nextChild: () -> BeamElement? = {
            if index < self.children.count {
                let child = self.children[index]
                index += 1
                return child
            }
            return nil
        }

        let nextOtherChild: () -> BeamElement? = {
            if otherIndex < other.children.count {
                let child = other.children[otherIndex]
                otherIndex += 1
                return child
            }
            return nil
        }

        let append: (BeamElement?, inout Set<UUID>) -> Void = { newChild, alreadyPlaced in
            guard let newChild = newChild else { return }
            newChildren.append(newChild)
            alreadyPlaced.insert(newChild.id)
        }

        var child = nextChild()
        var otherChild = nextOtherChild()

        while child != nil || otherChild != nil {
            if let _child = child, alreadyPlaced.contains(_child.id) {
                // child has been attached previously, let's skip it
                child = nextChild()
                continue
            }

            if let _otherChild = otherChild, alreadyPlaced.contains(_otherChild.id) {
                // otherChild has been attached previously, let's skip it
                otherChild = nextOtherChild()
                continue
            }

            if child?.id != otherChild?.id {
                if let _otherChild = otherChild {
                    let newChild = _otherChild.nonRecursiveCopy
                    append(newChild, &alreadyPlaced)

                    newChild?.mergeChildren(other: _otherChild, alreadyPlaced: &alreadyPlaced, otherElements: otherElements)
                    otherChild = nextOtherChild()
                } else if let _child = child {
                    let newChild = _child
                    append(newChild, &alreadyPlaced)

                    if let other = otherElements[_child.id] {
                        newChild.mergeChildren(other: other, alreadyPlaced: &alreadyPlaced, otherElements: otherElements)
                    }
                    child = nextChild()
                }
            } else if let _child = child, let _otherChild = otherChild {
                append(_child, &alreadyPlaced)
                _child.mergeChildren(other: _otherChild, alreadyPlaced: &alreadyPlaced, otherElements: otherElements)

                child = nextChild()
                otherChild = nextOtherChild()
            } else if let _child = child {
                append(_child, &alreadyPlaced)
                if let other = otherElements[_child.id] {
                    _child.mergeChildren(other: other, alreadyPlaced: &alreadyPlaced, otherElements: otherElements)
                }
                child = nextChild()
            } else if let _otherChild = otherChild {
                if let newChild = _otherChild.nonRecursiveCopy {
                    append(newChild, &alreadyPlaced)
                    if let other = otherElements[newChild.id] {
                        newChild.mergeChildren(other: other, alreadyPlaced: &alreadyPlaced, otherElements: otherElements)
                    }
                }
                child = nextChild()
            }
        }

        replaceChildren(newChildren)
    }
}
