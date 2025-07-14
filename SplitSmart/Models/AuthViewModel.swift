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
        // Defer auth state check to avoid blocking app startup and ensure Firebase is ready
        Task {
            // Small delay to ensure Firebase is fully configured
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await checkAuthState()
        }
    }
    
    private func checkAuthState() async {
        // Only check auth state once Firebase is configured
        guard !isInitialized else { return }
        isInitialized = true
        
        print("🔵 Checking authentication state...")
        
        // Wait for Firebase to be fully ready
        var retries = 0
        while FirebaseApp.app() == nil && retries < 50 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
            retries += 1
        }
        
        if FirebaseApp.app() == nil {
            print("❌ Firebase still not ready after retries")
            await MainActor.run {
                self.isInitializing = false
            }
            return
        }
        
        print("✅ Firebase is ready, checking current user...")
        
        // Check if we have a current user
        if let user = Auth.auth().currentUser {
            print("✅ Found existing user: \(user.email ?? "Unknown")")
            await MainActor.run {
                self.user = user
                self.isSignedIn = true
                self.isInitializing = false
            }
        } else {
            print("ℹ️ No existing user found")
            await MainActor.run {
                self.isInitializing = false
            }
        }
    }
    
    func signInWithGoogle() async {
        print("🔵 Starting Google Sign-In process...")
        
        // Ensure we're not already loading
        guard !isLoading else {
            print("❌ Already in loading state, ignoring tap")
            return
        }
        
        // Check Firebase configuration
        guard let firebaseApp = FirebaseApp.app() else {
            await MainActor.run {
                self.errorMessage = "Firebase not configured"
            }
            print("❌ Firebase app not found")
            return
        }
        
        guard let clientID = firebaseApp.options.clientID else {
            await MainActor.run {
                self.errorMessage = "Firebase configuration error - missing client ID"
            }
            print("❌ Firebase client ID not found")
            return
        }
        
        print("✅ Firebase client ID found: \(String(clientID.prefix(10)))...")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Unable to get root view controller"
            }
            print("❌ Root view controller not found")
            return
        }
        
        print("✅ Root view controller found")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        print("🔵 Starting Google Sign-In flow...")
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ Google Sign-In completed successfully")
            
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "Failed to get ID token from Google"
                    self.isLoading = false
                }
                print("❌ Failed to get ID token")
                return
            }
            
            print("✅ ID token obtained")
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            print("🔵 Signing in to Firebase...")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Firebase authentication successful")
            
            await MainActor.run {
                self.user = authResult.user
                self.isSignedIn = true
                self.isLoading = false
                print("✅ User signed in: \(authResult.user.email ?? "Unknown email")")
            }
            
        } catch {
            print("❌ Sign-in error: \(error.localizedDescription)")
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