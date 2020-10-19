import SwiftUI

struct NotesContentView: View {
    @State var selectedNote: Note?

    let context = CoreDataManager.shared.mainContext
    let viewModel = NoteList.ViewModel(managedObjectContext: CoreDataManager.shared.mainContext)

    func selectFirstNote() {
        selectedNote = viewModel.notes.first
    }

    var body: some View {
        NoteList(viewModel: viewModel, selectedNote: $selectedNote)
            .environment(\.managedObjectContext, context)
    }
}

struct NotesContentView_Previews: PreviewProvider {
    static var previews: some View {
        NotesContentView().background(Color.white)
    }
}
