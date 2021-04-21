import Foundation
import SwiftUI
import BeamCore

struct ShootFrame: View {
    @EnvironmentObject var state: BeamState

    @ObservedObject var pointAndShootUI: PointAndShootUI

    var body: some View {
        ZStack {
            let groups = pointAndShootUI.groupsUI
            ForEach(groups, id: \.id) { group in
                ShootFrameSelectionView(group: group)
                if group.edited {
                    if let selectionUI = group.uis.last {
                        ShootAbsolutePositioning(location: selectionUI.target.mouseLocation,
                                                 contentSize: ShootCardPicker.size) {
                            ShootCardPicker(focusOnAppear: pointAndShootUI.isTextSelectionFinished)
                                    .onComplete { (noteTitle, note) in
                                        onCompleteCardSelection(noteTitle, withNote: note)
                                    }
                        }
                    }
                }
            }
            if let confirmationUI = pointAndShootUI.shootConfirmation {
                ShootAbsolutePositioning(location: confirmationUI.target.mouseLocation,
                                         contentSize: ShootCardConfirmationView.size) {
                    ShootCardConfirmationView(noteTitle: confirmationUI.noteTitle,
                                              numberOfElements: confirmationUI.numberOfElements,
                                              isText: confirmationUI.isText)
                }
            }
        }
                .animation(nil)
    }

    func onCompleteCardSelection(_ noteTitle: String?, withNote note: String?) {
        if let noteTitle = noteTitle {
            pointAndShootUI.groupsUI.last!.edited = false   // Find edited one instead of assuming last
            do {
                try state.currentTab?.messageHandler?.pointAndShoot.addShootToNote(noteTitle: noteTitle, withNote: note)
            } catch let error {
                Logger.shared.logError("Could not add selection to card: \(error.localizedDescription)",
                                       category: .pointAndShoot)
            }
        }
        state.currentTab?.cancelShoot()
    }
}
