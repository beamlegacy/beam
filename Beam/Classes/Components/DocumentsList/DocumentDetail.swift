import SwiftUI

struct DocumentDetail: View {
    @State private var refreshing = false

    let document: Document
    let documentManager = DocumentManager()

    var body: some View {

        ScrollView {
            RefreshButton.padding()

            HStack {
                VStack {
                    HStack {
                        Text("ID:").bold()
                        Text(document.uuidString)
                        Spacer()
                    }
                    HStack {
                        Text("Title:").bold()
                        Text(document.title)
                        Spacer()
                    }
                    HStack {
                        Text("Created At:").bold()
                        Text(String(describing: document.created_at))
                        Spacer()
                    }
                    HStack {
                        Text("Updated At:").bold()
                        Text(String(describing: document.updated_at))
                        Spacer()
                    }
                    if let deleted_at = document.deleted_at {
                        HStack {
                            Text("Deleted At:").bold()
                            Text(String(describing: deleted_at))
                            Spacer()
                        }
                    }
                    if let data = document.data {
                        Spacer()

                        HStack {
                            Text(String(data: data, encoding: .utf8) ?? "Can't convert data")
                                .fontWeight(.light)
                                .background(Color.white)
                            Spacer()
                        }
                    }
                }.background(Color.white).padding()
                Spacer()
            }
            Spacer()
        }.onAppear {
            refresh()
        }
    }

    func refresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            refreshing = true
        }

        documentManager.refreshDocument(DocumentStruct(document: document)) { _ in
            DispatchQueue.main.async {
                timer.invalidate()
                refreshing = false
            }
        }
    }

    private var RefreshButton: some View {
        Button(action: {
            refresh()
        }, label: {
            if refreshing {
                Text("Refreshing").frame(minWidth: 100)
            } else {
                Text("Refresh").frame(minWidth: 100)
            }
        }).disabled(refreshing)
    }
}

struct DocumentDetail_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext
        let document = Document.fetchFirst(context: context)!

        return DocumentDetail(document: document).background(Color.white)
    }
}
