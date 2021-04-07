import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            TextField("Search ...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onTapGesture {
                    self.isEditing = true
                }

            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                }, label: {
                    Text("Cancel")
                })
                .padding(.trailing, BeamSpacing._100)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }

    public struct CustomTFStyle: TextFieldStyle {
        // swiftlint:disable identifier_name
        public func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding(7)
                .padding(.horizontal, 15)
                .cornerRadius(8)
                .foregroundColor(.black)
        }
        // swiftlint:disable identifier_name
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        SearchBar(text: .constant(""))
    }
}
