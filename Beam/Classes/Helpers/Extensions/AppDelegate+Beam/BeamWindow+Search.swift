//
//  BeamWindow+Search.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 28/09/2021.
//

import Foundation

extension BeamWindow {

    @IBAction func performFindPanelAction(_ sender: Any?) {
        switch state.mode {
        case .web:
            state.browserTabsManager.currentTab?.searchInContent()
        case .note:
            state.currentEditor?.searchInNote(fromSelection: false)
        default:
            break
        }
    }

    @IBAction func performFindNextPanelAction(_ sender: Any?) {
        switch state.mode {
        case .web:
            state.browserTabsManager.currentTab?.searchViewModel?.next()
        case .note:
            state.currentEditor?.searchViewModel?.next()
        default:
            break
        }
    }

    @IBAction func performFindPreviousPanelAction(_ sender: Any?) {
        switch state.mode {
        case .web:
            state.browserTabsManager.currentTab?.searchViewModel?.previous()
        case .note:
            state.currentEditor?.searchViewModel?.previous()
        default:
            break
        }
    }

    @IBAction func performFindPanelActionFromSelection(_ sender: Any?) {
        switch state.mode {
        case .web:
            state.browserTabsManager.currentTab?.searchInContent(fromSelection: true)
        case .note:
            state.currentEditor?.searchInNote(fromSelection: true)
        default:
            break
        }
    }
}
