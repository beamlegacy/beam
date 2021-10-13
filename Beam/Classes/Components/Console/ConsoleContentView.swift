import SwiftUI
import BeamCore

struct ConsoleContentView: View {
    @State private var logArray = Logger.shared.logFileString.split(separator: "\n")
    @State private var offset: CGPoint = .zero
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    @State private var scrollView: ScrollViewProxy?

    var body: some View {
        ScrollView {
            ScrollViewReader { scrollView in
                BottomButton.padding()
                Logs.padding().onAppear {
                    self.scrollView = scrollView
                    self.bottom()
                }.onReceive(timer) { _ in
                    logArray = Logger.shared.logFileString.split(separator: "\n")
                    bottom()
                }
            }
        }
        .background(BeamColor.Generic.background.swiftUI)
    }

    private var BottomButton: some View {
        Button(action: {
            bottom()
        }, label: {
            Text("Bottom").frame(minWidth: 100)
        })
    }

    private func bottom() {
        withAnimation(.easeInOut(duration: 0.15)) {
            scrollView?.scrollTo(logArray.count - 1, anchor: .top)
        }
    }

    private var Logs: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    ForEach(0..<logArray.count, id: \.self) { index in
                        Text(logArray[index])
                            .font(.system(size: 10, design: .monospaced))
                            // .id(index)
                    }
                    Spacer()
                }
                Spacer()
            }
            Spacer()
        }
    }
}

struct ConsoleContentView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleContentView().background(Color.white)
    }
}
