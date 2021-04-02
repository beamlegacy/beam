import SwiftUI
import Combine
import BeamCore

struct DocumentsList: View {
    @ObservedObject var viewModel: ViewModel
    @State private var searchText: String = ""
    @Binding var selectedDocument: Document?

    var body: some View {
        NavigationView {
            VStack {
                List(viewModel.documents, selection: $selectedDocument) { document in
                    NavigationLink(destination: DocumentDetail(document: document).background(Color.white)) {
                        DocumentRow(document: document)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 280)
            }

            if let selectedDocument = selectedDocument {
                DocumentDetail(document: selectedDocument)
            }
        }
    }
}

extension DocumentsList {
    final class ViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        private let managedObjectContext: NSManagedObjectContext
        private let documentsController: NSFetchedResultsController<Document>

        init(managedObjectContext: NSManagedObjectContext) {
            self.managedObjectContext = managedObjectContext
            let sortDescriptors = [NSSortDescriptor(keyPath: \Document.title, ascending: true)]
            documentsController = Document.resultsController(context: managedObjectContext, sortDescriptors: sortDescriptors)
            super.init()
            documentsController.delegate = self
            try? documentsController.performFetch()
            observeChangeNotification()
        }

        func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            objectWillChange.send()
        }

        var documents: [Document] {
            return documentsController.fetchedObjects ?? []
        }

        private var cancellables = [AnyCancellable]()

        private func observeChangeNotification() {
            NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange,
                                                 object: managedObjectContext)
                .compactMap({ ManagedObjectContextChanges<Document>(notification: $0) })
                .sink { changes in
                    Logger.shared.logDebug("\(changes)", category: .coredata)
                }
                .store(in: &cancellables)
        }
    }
}

struct DocumentsList_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = DocumentsList.ViewModel(managedObjectContext: CoreDataManager.shared.mainContext)
        let document = viewModel.documents.first
        return DocumentsList(viewModel: viewModel, selectedDocument: .constant(document))
    }
}
