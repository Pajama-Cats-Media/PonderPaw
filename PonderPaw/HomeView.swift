import SwiftUI
import FirebaseAuth

/// The HomeView includes the StoriesView as a child, passing in the current user's Firebase ID.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                // You can include other views or elements here.
                if let userId = Auth.auth().currentUser?.uid {
                    // Embed the StoriesView, passing the current Firebase user id.
                    StoriesView(userId: userId)
                } else {
                    Text("User not logged in")
                }
            }
            .padding()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
