import SwiftUI
import Combine

struct NoteList: View {
    @ObservedObject var viewModel: ViewModel
    @State var searchText: String = ""
    @Binding var selectedNote: Note?

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText).padding()

                List(viewModel.notes, selection: $selectedNote) { note in
                    NavigationLink(destination: NoteDetail(note: note).background(Color.white)) {
                        NoteRow(note: note)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 280)
            }

            if let selectedNote = selectedNote {
                NoteDetail(note: selectedNote)
            }
        }
    }
}

struct NoteList_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = NoteList.ViewModel(managedObjectContext: CoreDataManager.shared.mainContext)
        let note = viewModel.notes.first
        return NoteList(viewModel: viewModel, selectedNote: .constant(note))
    }
}
