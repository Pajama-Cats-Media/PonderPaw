import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Background image
            Image("bg") // Replace with your image name
                .resizable()
                .scaledToFill()
                .ignoresSafeArea() // Ensures the image covers the entire screen
            
            VStack {
                ConversationalAIView() // Main content is displayed here
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
