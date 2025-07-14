import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isInitializing = true
    
    private var isInitialized = false
    
    init() {
        // Defer auth state check to avoid blocking app startup
        Task {
            await checkAuthState()
        }
    }
    
    private func checkAuthState() async {
        // Only check auth state once Firebase is configured
        guard !isInitialized else { return }
        isInitialized = true
        
        // Check if we have a current user
        if let user = Auth.auth().currentUser {
            await MainActor.run {
                self.user = user
                self.isSignedIn = true
                self.isInitializing = false
            }
        } else {
            await MainActor.run {
                self.isInitializing = false
            }
        }
    }
    
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            await MainActor.run {
                self.errorMessage = "Firebase configuration error"
            }
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Unable to get root view controller"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "Failed to get ID token"
                    self.isLoading = false
                }
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: result.user.accessToken.tokenString)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            
            await MainActor.run {
                self.user = authResult.user
                self.isSignedIn = true
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            self.isSignedIn = false
            self.errorMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}