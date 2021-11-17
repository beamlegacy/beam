import SwiftUI
import Combine
import BeamCore

struct DocumentsList: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Document.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Document.title,
                                                     ascending: true)])
    var documents: FetchedResults<Document>

    @State private var searchText: String = ""
    @Binding var selectedDocument: Document?

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                List(documents.filter({
                    searchText.isEmpty ? true :
                        ($0.title.range(of: searchText, options: .caseInsensitive) != nil) ||
                        ($0.data?.asString?.range(of: searchText, options: .caseInsensitive) != nil ||
                            $0.id.uuidString.lowercased() == searchText.lowercased())
                }), selection: $selectedDocument) { document in
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
        let documentManager = DocumentManager()
        //swiftlint:disable:next force_try
        let document = try! documentManager.fetchFirst()
        return DocumentsList(selectedDocument: .constant(document))
    }
}
