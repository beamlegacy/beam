import Foundation
import SwiftUI
import BeamCore

struct ShootFrame: View {
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @ObservedObject var pns: PointAndShoot

    var body: some View {
        if let group = pns.activeShootGroup {
            ZStack {
                ShootFrameSelectionView(pns: pns, webPositions: pns.webPositions, group: group)
                ShootAbsolutePositioning(pns: pns, webPositions: pns.webPositions, group: group, contentSize: ShootCardPicker.size) {
                    ShootCardPicker()
                        .onComplete { (noteTitle, note) in
                            onCompleteCardSelection(noteTitle, withNote: note)
                        }
                }
            }
        }
    }

    func onCompleteCardSelection(_ noteTitle: String?, withNote note: String?) {
        if let noteTitle = noteTitle {
            browserTabsManager.currentTab?.pointAndShoot?.addShootToNote(noteTitle: noteTitle, withNote: note)
        } else {
            browserTabsManager.currentTab?.cancelShoot()
        }
    }
}
