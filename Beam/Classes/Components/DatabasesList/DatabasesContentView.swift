import SwiftUI

struct DatabasesContentView: View {
    @State private var selectedDatabase: Database?

    var body: some View {
        DatabasesList(selectedDatabase: $selectedDatabase)
            .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
    }
}

struct DatabasesContentView_Previews: PreviewProvider {
    static var previews: some View {
        DatabasesContentView().background(Color.white)
    }
}
