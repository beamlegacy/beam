import SwiftUI
import Combine
import BeamCore

struct DocumentDetail: View {
    @State private var refreshing = false

    @ObservedObject var document: Document
    let documentManager = DocumentManager()
    let databaseManager = DatabaseManager()

    var body: some View {
        if document.managedObjectContext != nil {
            ScrollView {
                HStack(alignment: VerticalAlignment.center, spacing: 10.0) {
                    RefreshButton
                    SaveButton
                    SoftDeleteButton
                    SoftUnDeleteButton
                    LocalDeleteButton
                    DeleteButton
                    PublicButton
                    DatabasePicker
                    Spacer()
                }.padding()

                HStack {
                    VStack {
                        if let date = document.journal_day, date != 0 {
                            HStack {
                                Text("Journal Date:").bold()
                                Text(JournalDateConverter.toString(from: date))
                                Spacer()
                            }
                        }
                        VStack {
                            HStack {
                                Text("ID:").bold()
                                Text(document.uuidString)
                                Spacer()
                            }
                            HStack {
                                Text("Beam Object Checksum:").bold()
                                Text(DocumentStruct(document: document).previousChecksum ?? "-")
                                Spacer()
                            }
                            HStack {
                                Text("Type:").bold()
                                Text(document.document_type == 0 ? "Journal" : "Note")
                                Spacer()
                            }
                            HStack {
                                Text("Database:").bold()
                                Text((try? Database.fetchWithId(CoreDataManager.shared.mainContext,
                                                                document.database_id))?.title ?? "no database")
                                Text(document.database_id.uuidString)
                                Spacer()
                            }
                            HStack {
                                Text("Title:").bold()
                                Text(document.title)
                                Spacer()
                            }
                            HStack {
                                Text("Created At:").bold()
                                Text("\(document.created_at, formatter: Self.dateFormat)")
                                Spacer()
                            }
                            HStack {
                                Text("Updated At:").bold()
                                Text("\(document.updated_at, formatter: Self.dateFormat)")
                                Spacer()
                            }
                            if let deleted_at = document.deleted_at {
                                HStack {
                                    Text("Deleted At:").bold()
                                    Text("\(deleted_at, formatter: Self.dateFormat)")
                                    Spacer()
                                }
                            }
                            HStack {
                                Text("Public:").bold()
                                Text(document.is_public ? "Yes" : "No")
                                Spacer()
                            }
                            HStack {
                                Text("Version:").bold()
                                Text("\(document.version)")
                                Spacer()
                            }
                        }

                        Divider()

                        Spacer()

                        HStack(alignment: .top) {
                            VStack(alignment: HorizontalAlignment.leading) {
                                Text("Document Data")
                                Text(document.data?.asString ?? "No data")
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .background(Color.white)
                            }

                            Spacer()

                            VStack(alignment: HorizontalAlignment.leading) {
                                if DocumentStruct(document: document).hasLocalChanges {
                                    Text("Document Previous Data (differs from current data)")
                                } else {
                                    Text("Document Previous Data")
                                }
                                Text(DocumentStruct(document: document).previousSavedObject?.data.asString ?? "No ancestor data")
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .background(Color.white)
                            }
                            Spacer()
                        }

                        Divider()
                    }.background(Color.white).padding()
                    Spacer()
                }
                Spacer()
            }.onAppear {
                softRefresh()
                if let database = try? Database.fetchWithId(CoreDataManager.shared.mainContext, document.database_id) {
                    selectedDatabase = database
                }
            }
        } else {
            EmptyView()
        }
    }

    private func refresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }

        do {
            try documentManager.refresh(DocumentStruct(document: document), true) { _ in
                DispatchQueue.main.async {
                    timer.invalidate()
                    refreshing = false
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .document)
        }
    }

    private func softRefresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }

        do {
            try documentManager.refresh(DocumentStruct(document: document), false) { _ in
                DispatchQueue.main.async {
                    timer.invalidate()
                    refreshing = false
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .document)
        }
    }

    private func delete(_ remoteDelete: Bool = true) {
        documentManager.delete(document: DocumentStruct(document: document), remoteDelete) { _ in }
    }

    private func softDelete() {
        let documentStruct = DocumentStruct(document: document)

        documentManager.softDelete(id: documentStruct.id, completion: { _ in
        })
    }

    private func softUnDelete() {
        var documentStruct = DocumentStruct(document: document)
        documentStruct.deletedAt = nil
        documentStruct.version += 1

        documentManager.saveThenSaveOnAPI(documentStruct, completion: { _ in
        })
    }

    private func save() {
        var documentStruct = DocumentStruct(document: document)
        documentStruct.updatedAt = BeamDate.now
        documentStruct.version += 1

        documentManager.saveThenSaveOnAPI(documentStruct, completion: { _ in
        })
    }

    private func togglePublic() {
        var documentStruct = DocumentStruct(document: document)
        documentStruct.version += 1
        documentStruct.isPublic = !documentStruct.isPublic

        documentManager.saveThenSaveOnAPI(documentStruct, completion: { _ in
        })
    }

    private var RefreshButton: some View {
        Button(action: {
            refresh()
        }, label: {
            Text(refreshing ? "Refreshing" : "Refresh").frame(minWidth: 100)
        }).disabled(refreshing)
    }

    private var DeleteButton: some View {
        Button(action: {
            delete()
        }, label: {
            Text("Delete").frame(minWidth: 100)
        })
    }

    private var SoftUnDeleteButton: some View {
        Button(action: {
            softUnDelete()
        }, label: {
            Text("Recover").frame(minWidth: 100)
        })
    }

    private var LocalDeleteButton: some View {
        Button(action: {
            delete(false)
        }, label: {
            Text("Local Delete").frame(minWidth: 100)
        })
    }

    private var SoftDeleteButton: some View {
        Button(action: {
            softDelete()
        }, label: {
            Text("Soft Delete").frame(minWidth: 100)
        })
    }

    private var SaveButton: some View {
        Button(action: {
            save()
        }, label: {
            Text("Save").frame(minWidth: 100)
        })
    }

    private var PublicButton: some View {
        Button(action: {
            togglePublic()
        }, label: {
            Text(document.is_public ? "Make Private" : "Make Public").frame(minWidth: 100)
        })
    }

    @State private var selectedDatabase = Database.defaultDatabase()
    private var DatabasePicker: some View {
        Picker("", selection: $selectedDatabase.onChange(dbChange), content: {
            ForEach(databaseManager.all(), id: \.title) {
                Text($0.title).tag($0)
            }
        })
    }

    private func dbChange(_ db: Database) {
        guard document.database_id != db.id else { return }

        document.database_id = db.id

        var docStruct = DocumentStruct(document: document)
        docStruct.version += 1

        documentManager.save(docStruct, completion: { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .document)
            case .success:
                Logger.shared.logDebug("Document saved")
            }
        })
    }

    static private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        return formatter
    }()
}

struct DocumentDetail_Previews: PreviewProvider {
    static var previews: some View {
        let documentManager = DocumentManager()
        // swiftlint:disable:next force_try
        let document = try! documentManager.fetchFirst()!

        return DocumentDetail(document: document).background(Color.white)
    }
}
