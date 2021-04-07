import SwiftUI
import BeamCore

struct ConsoleContentView: View {
    @State private var logArray = Logger.shared.logFileString.split(separator: "\n")
    @State private var offset: CGPoint = .zero
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    @available(OSX 11.0, *)
    @State private var scrollView: ScrollViewProxy?

    var body: some View {
        ScrollView {
            if #available(macOS 11.0, iOS 14.0, *) {
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
            } else {
                Logs
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
        if #available(OSX 11.0, *) {
            withAnimation(.easeInOut(duration: 0.15)) {
                scrollView?.scrollTo(logArray.count - 1, anchor: .top)
            }
        } else {
            // Fallback on earlier versions
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
