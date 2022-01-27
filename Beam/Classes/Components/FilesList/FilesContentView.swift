import SwiftUI
import BeamCore
import GRDB

struct FilesContentView: View {
    @State private var selectedFile: BeamFileRecord?

    private let fileManager = BeamFileDBManager.shared

    var body: some View {
        FilesList(selectedFile: $selectedFile,
                  files: (try? fileManager.allObjects(updatedSince: nil)) ?? [])
    }
}
