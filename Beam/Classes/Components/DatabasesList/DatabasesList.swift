import SwiftUI
import Combine

struct DatabasesList: View {
    @Environment(\.managedObjectContext) var moc
    @Binding var selectedDatabase: Database?
    @FetchRequest(entity: Database.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Database.title, ascending: true)])
    var databases: FetchedResults<Database>
    let databaseManager = DatabaseManager()

    var body: some View {
        NavigationView {
            VStack {
                newDatabaseButton
                    .frame(maxWidth: .infinity, alignment: .center)

                List(databases, selection: $selectedDatabase) { database in
                    NavigationLink(destination: DatabaseDetail(database: database).background(Color.white)) {
                        DatabaseRow(database: database)
                            .environment(\.managedObjectContext, self.moc)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 280)
            }

            if let selectedDatabase = selectedDatabase {
                DatabaseDetail(database: selectedDatabase)
            }
        }.onAppear {
            selectedDatabase = try? Database.fetchWithId(moc, DatabaseManager.defaultDatabase.id)
        }
    }

    @State private var showNewDatabase = false
    @State private var newDatabaseTitle = ""
    private var newDatabaseButton: some View {
        Button(action: {
            showNewDatabase = true
        }, label: {
            Text("New Database").frame(minWidth: 100)
        })
        .popover(isPresented: $showNewDatabase) {
            HStack {
                TextField("title", text: $newDatabaseTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(minWidth: 100, maxWidth: 400)
                    .padding()

                Button(action: {
                    if !newDatabaseTitle.isEmpty {
                        let database = DatabaseStruct(title: newDatabaseTitle)
                        databaseManager.saveDatabase(database, completion: { result in
                            if case .success(let done) = result, done {
                                DispatchQueue.main.async {
                                    if let database = try? Database.fetchWithId(CoreDataManager.shared.mainContext, database.id) {
                                        DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
                                        try? CoreDataManager.shared.save()
                                    }
                                }
                            }
                            showNewDatabase = false
                        })
                    } else {
                        showNewDatabase = false
                    }
                    newDatabaseTitle = ""
                }, label: {
                    Text("Create")
                }).padding()
            }
        }
    }
}

struct DatabasesList_Previews: PreviewProvider {
    static var previews: some View {
        let database = Database.defaultDatabase(CoreDataManager.shared.mainContext)
        return DatabasesList(selectedDatabase: .constant(database))
            .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
    }
}
