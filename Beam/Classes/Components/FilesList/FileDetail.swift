import SwiftUI
import Combine
import BeamCore
import AppKit
import GRDB

struct FileDetail: View {
    @State var file: BeamFileRecord
    @State private var cancellable: DatabaseCancellable?
    @State private var refreshing = false
    @State private var deleted = false
    @State private var saving = false

    let fileManager: BeamFileDBManager
    private let formatter = ByteCountFormatter()

    var body: some View {
        if deleted {
            EmptyView()
        } else {
            ScrollView {
                HStack(alignment: VerticalAlignment.center, spacing: 10.0) {
                    RefreshButton
                    SoftDeleteButton
                    LocalDeleteButton
                    DeleteButton
                    SaveButton
                    PurgeUnlinked
                    PurgeUndo
                    Spacer()
                }.padding()

                HStack {
                    VStack {
                        VStack {
                            HStack {
                                Text("ID:").bold()
                                Text(file.beamObjectId.uuidString)
                                Spacer()
                            }
                            HStack {
                                Text("Checksum:").bold()
                                Text(file.previousChecksum ?? "-")
                                Spacer()
                            }
                            HStack {
                                Text("Previous Checksum:").bold()
                                Text(file.previousChecksum ?? "-")
                                Spacer()
                            }
                            HStack {
                                Text("Name:").bold()
                                Text(file.name)
                                Spacer()
                            }
                            HStack {
                                Text("Type:").bold()
                                Text(file.type)
                                Spacer()
                            }
                            if file.type[0..<6] == "image/",
                               let data = file.data,
                               let image = NSImage(data: data) {
                                HStack {
                                    Text("Width:").bold()
                                    Text("\(image.size.width)")
                                    Spacer()
                                }
                                HStack {
                                    Text("Height:").bold()
                                    Text("\(image.size.height)")
                                    Spacer()
                                }
                            }
                            HStack {
                                Text("Size:").bold()
                                Text("\(formatter.string(fromByteCount: Int64(file.data.count)))")
                                Spacer()
                            }
                            HStack {
                                Text("Created At:").bold()
                                Text("\(file.createdAt, formatter: Self.dateFormat)")
                                Spacer()
                            }
                            HStack {
                                Text("Updated At:").bold()
                                Text("\(file.updatedAt, formatter: Self.dateFormat)")
                                Spacer()
                            }
                            if let deleted_at = file.deletedAt {
                                HStack {
                                    Text("Deleted At:").bold()
                                    Text("\(deleted_at, formatter: Self.dateFormat)")
                                    Spacer()
                                }
                            }
                        }

                        Divider()
                        HStack {
                            Text("Reference count:").bold()
                            let count = (try? fileManager.referenceCount(fileId: file.id)) ?? 0
                            Text("\(count)")
                            Spacer()
                        }
                        Text( ((try? fileManager.referencesFor(fileId: file.id)) ?? []).map({ "\($0.note?.titleAndId ?? "???") - \($0.elementID)" }).joined(separator: "\n"))

                        Divider()

                        if file.type[0..<6] == "image/",
                           let data = file.data,
                           let image = NSImage(data: data) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: image.size.width / (NSScreen.main?.backingScaleFactor ?? 2),
                                       maxHeight: image.size.height / (NSScreen.main?.backingScaleFactor ?? 2))
                                .padding()
                        }

                        Spacer()
                    }.background(Color.white).padding()
                    Spacer()
                }
                Spacer()
            }.onAppear {
                self.cancellable = ValueObservation.tracking { db in
                    try BeamFileRecord.fetchOne(db, key: file.uid)
                }.start(in: fileManager.grdbStore.writer,
                        onError: { error in Logger.shared.logError(error.localizedDescription, category: .fileDB) },
                        onChange: { changedFile in
                    if let changedFile = changedFile {
                        self.file = changedFile
                    }})
            }
        }
    }

    private func refresh() {
        refreshing = true
        Task {
            do {
                defer {
                    refreshing = false
                }
                try await fileManager.refresh(file)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    private func delete(_ remoteDelete: Bool = true) {
        deleted = true

        do {
            try fileManager.remove(uid: file.uid)

            if remoteDelete {
                Task {
                    do {
                        try await fileManager.deleteFromBeamObjectAPI(object: file)
                    } catch {
                        Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                    }
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
        }
    }

    private func softDelete() {
        Task {
            file.deletedAt = BeamDate.now
            file.updatedAt = BeamDate.now

            do {
                try fileManager.insert(files: [file])
                try await fileManager.saveOnBeamObjectAPI(file)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    private var RefreshButton: some View {
        Button(action: {
            refresh()
        }, label: {
            Text(refreshing ? "Refreshing" : "Refresh").frame(minWidth: 100)
        }).disabled(refreshing || deleted)
    }

    private var DeleteButton: some View {
        Button(action: {
            delete()
        }, label: {
            Text("Delete").frame(minWidth: 100)
        }).disabled(deleted)
    }

    private var SaveButton: some View {
        Button(action: {
            saving = true
            Task {
                do {
                    try await fileManager.saveOnBeamObjectAPI(file, force: true)
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                }
                saving = false
            }
        }, label: {
            Text("Save").frame(minWidth: 100)
        }).disabled(deleted || saving)
    }

    private var PurgeUnlinked: some View {
        Button {
            try? fileManager.purgeUnlinkedFiles()
        } label: {
            Text("Purge unlinked files")
        }
    }

    private var PurgeUndo: some View {
        Button {
            try? fileManager.purgeUndo()
        } label: {
            Text("Purge undo files")
        }

    }
    private var LocalDeleteButton: some View {
        Button(action: {
            delete(false)
        }, label: {
            Text("Local Delete").frame(minWidth: 100)
        }).disabled(deleted)
    }

    private var SoftDeleteButton: some View {
        Button(action: {
            softDelete()
        }, label: {
            Text("Soft Delete").frame(minWidth: 100)
        }).disabled(deleted)
    }

    static private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        return formatter
    }()
}

struct FileDetail_Previews: PreviewProvider {
    static var previews: some View {
        let fileManager = AppData.shared.currentAccount?.fileDBManager
        let file = try! fileManager?.fetchRandom()

        return FileDetail(file: file!, fileManager: fileManager!).background(Color.white)
    }
}
