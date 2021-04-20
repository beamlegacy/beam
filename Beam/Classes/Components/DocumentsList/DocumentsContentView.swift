import SwiftUI

struct DocumentsContentView: View {
    @State private var selectedDocument: Document?

    var body: some View {
        DocumentsList(selectedDocument: $selectedDocument)
            .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
    }
}

struct DocumentsContentView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentsContentView().background(Color.white)
    }
}
