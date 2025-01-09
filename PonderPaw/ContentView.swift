import SwiftUI

struct ContentView: View {
    @State private var localServerURL: URL? = nil
    @State private var isServerStarting = true
    private let server = LocalHTTPServer()

    var body: some View {
        ZStack {
            if isServerStarting {
                Text("Starting server...")
            } else if let url = localServerURL {
                WebContentView(url: url)
                    .navigationBarTitle("Local Server", displayMode: .inline)
            } else {
                Text("Failed to start the server.")
            }

            VStack {
                ConversationalAIView() // Main content is displayed here
            }
        }
        .onAppear {
            startLocalServer()
        }
        .onDisappear {
            stopLocalServer()
        }
    }

    private func startLocalServer() {
        DispatchQueue.global(qos: .background).async {
                        
            guard let folderPath = Bundle.main.path(forResource: "book", ofType: nil) else {
                print("Failed to locate 'book' directory in the project.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                }
                return
            }

            if let urlString = server.startServer(folderPath: folderPath),
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    self.localServerURL = url
                    self.isServerStarting = false
                }
            } else {
                print("Failed to start the local server.")
                DispatchQueue.main.async {
                    self.isServerStarting = false
                }
            }
        }
    }

    private func stopLocalServer() {
        server.stopServer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
