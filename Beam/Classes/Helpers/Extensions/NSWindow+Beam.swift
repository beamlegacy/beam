//
//  NSWindow+Beam.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 12/05/2022.
//

import Foundation

extension NSWindow {
    func highestParentOrClosestMiniEditor() -> NSWindow {
        guard !(self is MiniEditorPanel) else { return self }
        guard let parent = self.parent else { return self }
        return parent.highestParentOrClosestMiniEditor()
    }
}
