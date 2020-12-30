import SwiftUI

struct DocumentDetail: View {
    var document: Document

    var body: some View {
        ScrollView {
            HStack {
                VStack {
                    if let data = document.data {
                        Text(String(data: data, encoding: .utf8) ?? "Can't convert data")
                            .background(Color.white)
                    } else {
                        Text("No Data")
                    }
                }.background(Color.white).padding()
                Spacer()
            }
            Spacer()
        }
    }
}

struct DocumentDetail_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext
        let document = Document.fetchFirst(context: context)!

        return DocumentDetail(document: document).background(Color.white)
    }
}
