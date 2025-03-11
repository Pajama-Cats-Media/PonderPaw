import SwiftUI
import FirebaseAuth

struct UserView: View {
    @Environment(\.dismiss) private var dismiss  // To navigate back
    @State private var userName: String? = nil  // Store user's name
    
    var body: some View {
        VStack(spacing: 20) {
            Text("👤 Profile View")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let userName = userName {
                Text("Welcome, \(userName)!")
                    .font(.headline)
                    .foregroundColor(.primary)
            } else {
                Text("Fetching user info...")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            Button(action: logout) {
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
        .onAppear {
            fetchUserName()
        }
    }
    
    private func fetchUserName() {
        if let user = Auth.auth().currentUser {
            userName = user.displayName ?? "User"
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
