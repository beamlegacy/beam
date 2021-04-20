import SwiftUI
import BeamCore

struct DatabaseRow: View {
    @ObservedObject var database: Database
    @State private var showingAlert = false
    @Environment(\.managedObjectContext) var moc

    let databaseManager = DatabaseManager()

    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        HStack {
            if database.managedObjectContext != nil {
                VStack {

                    if database == Database.defaultDatabase() {
                        Text(database.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.headline)
                    } else {
                        Text(database.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.callout)
                    }

                    Text("\(database.created_at, formatter: Self.taskDateFormat)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.footnote)

                    Text("\(database.documentsCount()) notes")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.footnote)

                    if database.isDeleted || database.deleted_at != nil {
                        Text("deleted")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.footnote)
                    }
                }

                Spacer()

                Button("Delete") {
                    showingAlert = true
                    let dbStruct = DatabaseStruct(database: database)
                    databaseManager.deleteDatabase(dbStruct) { _ in
                        Logger.shared.logInfo("database \(dbStruct.title) deleted")
                    }
                }
            }

            //            .alert(isPresented: $showingAlert) {
            //                Alert(
            //                    title: Text("Delete \(database.title)?"),
            //                    message: Text("Deleting database will delete all data related to it. There is no undo"),
            //                    primaryButton: .destructive(Text("Delete")) {
            //                        let dbStruct = DatabaseStruct(database: database)
            //                        databaseManager.deleteDatabase(dbStruct) { _ in
            //                            Logger.shared.logInfo("database \(dbStruct.title) deleted")
            //                        }
            //                    },
            //                    secondaryButton: .cancel()
            //                )
            //            }
        }
        .padding()
    }
}

struct DatabaseRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if let database = try? Database.fetchFirst(context: CoreDataManager.shared.mainContext) {
                DatabaseRow(database: database)
            }
        }.previewLayout(.fixed(width: 400, height: 100))
    }
}
