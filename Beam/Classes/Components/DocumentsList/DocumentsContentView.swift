import SwiftUI

struct DocumentsContentView: View {
    @State var selectedDocument: Document?

    let context = CoreDataManager.shared.mainContext
    let viewModel = DocumentsList.ViewModel(managedObjectContext: CoreDataManager.shared.mainContext)

    func selectFirstNote() {
        selectedDocument = viewModel.documents.first
    }

    var body: some View {
        DocumentsList(viewModel: viewModel, selectedDocument: $selectedDocument)
            .environment(\.managedObjectContext, context)
    }
}

struct DocumentsContentView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentsContentView().background(Color.white)
    }
}
