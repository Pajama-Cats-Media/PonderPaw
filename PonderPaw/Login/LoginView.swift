import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isCreatingAccount = false
    @State private var isLoading = false // Loading state

    var body: some View {
        // Use ZStack to center the login form in the main view.
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // The login form is now the main panel.
            VStack(spacing: 16) {
                Text("Login PaperHeart Viewer")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 20)
                
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                SecureField("Enter your password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    loginWithEmailPassword()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(isCreatingAccount ? "Create Account" : "Log In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    isCreatingAccount.toggle()
                }) {
                    Text(isCreatingAccount ? "Already have an account? Log in" : "Create an account")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Button(action: {
                    signInWithGoogle()
                }) {
                    HStack {
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.horizontal, 20)
        }
    }
    
    func loginWithEmailPassword() {
        errorMessage = ""
        isLoading = true
        
        let auth = Auth.auth()
        
        if isCreatingAccount {
            auth.createUser(withEmail: email, password: password) { result, error in
                self.isLoading = false
                if let error = error as NSError? {
                    self.handleAuthError(error)
                    return
                }
                // Successful account creation
                self.isLoggedIn = true
            }
        } else {
            auth.signIn(withEmail: email, password: password) { result, error in
                self.isLoading = false
                if let error = error as NSError? {
                    self.handleAuthError(error)
                    return
                }
                // Successful login
                self.isLoggedIn = true
            }
        }
    }
    
    func handleAuthError(_ error: NSError) {
        switch error.code {
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "Invalid email format"
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "Password must be at least 6 characters"
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "User not found"
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Incorrect password"
        default:
            errorMessage = error.localizedDescription
        }
    }
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        isLoading = true

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.isLoading = false
                self.errorMessage = "Could not get tokens from Google Sign In"
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { _, error in
                self.isLoading = false
                if let error = error as NSError? {
                    self.errorMessage = error.localizedDescription
                    return
                }
                // Successful Google sign-in
                self.isLoggedIn = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isLoggedIn: .constant(false))
    }
}
