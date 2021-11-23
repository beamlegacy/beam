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

    private let fileManager = BeamFileDBManager()
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
                                Text(file.checksum ?? "-")
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
                }.start(in: BeamFileDBManager.fileDB.dbPool,
                        onError: { error in Logger.shared.logError(error.localizedDescription, category: .fileDB) },
                        onChange: { changedFile in
                    if let changedFile = changedFile {
                        self.file = changedFile
                    }})
            }
        }
    }

    private func refresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }

        do {
            try fileManager.refresh(file) { _ in
                DispatchQueue.main.async {
                    timer.invalidate()
                    refreshing = false
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
        }
    }

    private func delete(_ remoteDelete: Bool = true) {
        deleted = true

        do {
            try BeamFileDBManager.fileDB.remove(uid: file.uid)

            if remoteDelete {
                try fileManager.deleteFromBeamObjectAPI(file.beamObjectId) { result in
                    switch result {
                    case .success: break
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                    }
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
        }
    }

    private func softDelete() {
        self.file.deletedAt = BeamDate.now

        do {
            try BeamFileDBManager.fileDB.insert(files: [file])
            try fileManager.saveOnBeamObjectAPI(file) { result in
                switch result {
                case .success: break
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
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
            let backgroundQueue = DispatchQueue(label: "FileDetail BeamObjectManager backgroundQueue", qos: .userInitiated)

            backgroundQueue.async {
                do {
                    saving = true

                    try fileManager.saveOnBeamObjectAPI(file) { result in
                        saving = false

                        switch result {
                        case .success: break
                        case .failure(let error):
                            Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                        }
                    }
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
                }
            }
        }, label: {
            Text("Save").frame(minWidth: 100)
        }).disabled(deleted || saving)
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
        // swiftlint:disable:next force_try
        let file = try! (try! BeamFileDB(path: BeamData.fileDBPath)).fetchRandom()

        return FileDetail(file: file!).background(Color.white)
    }
}
