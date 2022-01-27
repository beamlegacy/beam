import SwiftUI
import Combine
import BeamCore
import GRDB

struct FilesList: View {
    @Binding var selectedFile: BeamFileRecord?

    @State var files: [BeamFileRecord]
    @State private var cancellable: DatabaseCancellable?
    @State private var searchText: String = ""

    private let fileManager = BeamFileDBManager.shared

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                List(files.filter({
                    searchText.isEmpty ? true :
                        ($0.name.range(of: searchText, options: .caseInsensitive) != nil) ||
                    $0.id.uuidString.lowercased() == searchText.lowercased()
                }), selection: $selectedFile) { file in
                    NavigationLink(destination: FileDetail(file: file).background(Color.white)) {
                        FileRow(file: file)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 280)
            }
        }.onAppear {
            self.cancellable = ValueObservation
                .tracking { db in
                    try BeamFileRecord.fetchAll(db)
                }
                .start(in: BeamFileDBManager.shared.dbPool,
                       onError: { Logger.shared.logError($0.localizedDescription, category: .fileDB) },
                       onChange: { self.files = $0 })
        }
    }
}
