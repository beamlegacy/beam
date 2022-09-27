//
//  EditorType.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/09/2022.
//

public enum EditorType {
    case main
    case splitView
    case panel(_ existingPanel: MiniEditorPanel?)

    var isMiniEditor: Bool {
        switch self {
        case .splitView, .panel:
            return true
        default:
            return false
        }
    }

    /// This is used to define which editor is the "alternate", and so which one we should use when clicking a link while holding cmd
    var alternate: EditorType {
        switch self {
        case .main:
            return .splitView
        case .splitView:
            return .main
        case .panel:
            return .panel(nil)
        }
    }
}
