import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var isLoggedIn: Bool = Auth.auth().currentUser != nil

    var body: some View {
        NavigationStack {
            if isLoggedIn {
                // Show bottom tab navigation if user is logged in
                TabView {
                    StoriesView(userId: Auth.auth().currentUser?.uid ?? "")
                        .tabItem {
                            Image(systemName: "doc.text") // Document icon
                            Text("Documents")
                        }

                    ScanView()
                        .tabItem {
                            Image(systemName: "camera.viewfinder") // Scan icon
                            Text("Scan")
                        }

                    UserView()
                        .tabItem {
                            Image(systemName: "person.crop.circle") // Profile icon
                            Text("Profile")
                        }
                }
            } else {
                // Show login screen if user is not logged in
                VStack(spacing: 20) {
                    Text("Welcome to the App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Button(action: login) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .onAppear {
            listenForAuthChanges()
        }
    }

    /// Listens for authentication state changes
    private func listenForAuthChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            isLoggedIn = user != nil
        }
    }

    /// Dummy login function (replace with real Firebase login logic)
    private func login() {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("Login failed: \(error.localizedDescription)")
            } else {
                print("Logged in as: \(result?.user.uid ?? "Unknown")")
                isLoggedIn = true  // Update UI
            }
        }
    }
}
