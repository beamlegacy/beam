import SwiftUI
import Combine
import BeamCore

struct DocumentsList: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Document.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Document.title, ascending: true)])
    var documents: FetchedResults<Document>

    @State private var searchText: String = ""
    @Binding var selectedDocument: Document?

    var body: some View {
        NavigationView {
            VStack {
                List(documents, selection: $selectedDocument) { document in
                    NavigationLink(destination: DocumentDetail(document: document).background(Color.white)) {
                        DocumentRow(document: document)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 280)
            }

            if let selectedDocument = selectedDocument, selectedDocument.managedObjectContext != nil {
                DocumentDetail(document: selectedDocument)
            }
        }
    }
}

struct DocumentsList_Previews: PreviewProvider {
    static var previews: some View {
        //swiftlint:disable:next force_try
        let document = try! Document.fetchFirst(CoreDataManager.shared.mainContext)
        return DocumentsList(selectedDocument: .constant(document))
    }
}
