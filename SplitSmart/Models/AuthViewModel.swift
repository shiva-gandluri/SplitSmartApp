import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
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
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        // Add small delay to prevent rapid successive calls
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Unable to get root view controller"
                self.isLoading = false
            }
            print("❌ Root view controller not found")
            return
        }
        
        print("✅ Root view controller found")
        print("🔵 Starting Google Sign-In flow...")
        
        do {
            // Use the Google Sign-In that's already configured in AppDelegate
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ Google Sign-In completed successfully")
            
            // Check if we're still in loading state (user might have cancelled)
            guard isLoading else {
                print("ℹ️ Sign-in cancelled or already completed")
                return
            }
            
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
            
            // Create user record in Firestore (with error handling) - non-blocking
            Task {
                do {
                    try await createUserRecord(authResult: authResult)
                } catch {
                    print("⚠️ Warning: Failed to create user record, but continuing with auth: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.user = authResult.user
                self.isSignedIn = true
                self.isLoading = false
                print("✅ User signed in: \(authResult.user.email ?? "Unknown email")")
            }
            
        } catch {
            print("❌ Sign-in error: \(error.localizedDescription)")
            await MainActor.run {
                // Handle specific error types
                if let nsError = error as NSError? {
                    switch nsError.code {
                    case -5: // User cancelled
                        self.errorMessage = ""
                        print("ℹ️ User cancelled sign-in")
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
    
    private func createUserRecord(authResult: AuthDataResult) async throws {
        print("🔵 Attempting to create user record in Firestore...")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(authResult.user.uid)
        
        // Set a timeout for Firestore operations to prevent hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            throw NSError(domain: "FirestoreTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firestore operation timed out"])
        }
        
        let firestoreTask = Task {
            do {
                // Check if user already exists with offline support
                let document = try await userRef.getDocument(source: .default)
                
                if !document.exists {
                    print("🔵 Creating new user record in Firestore...")
                    
                    let userData: [String: Any] = [
                        "uid": authResult.user.uid,
                        "email": authResult.user.email ?? "",
                        "displayName": authResult.user.displayName,
                        "authProvider": "google.com",
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSignInAt": FieldValue.serverTimestamp()
                    ].compactMapValues { $0 }
                    
                    try await userRef.setData(userData, merge: true)
                    print("✅ User record created in Firestore")
                } else {
                    print("ℹ️ User record already exists, updating last sign-in time")
                    try await userRef.updateData([
                        "lastSignInAt": FieldValue.serverTimestamp()
                    ])
                }
            } catch let error as NSError {
                // Handle specific Firestore errors
                if error.domain == FirestoreErrorDomain {
                    switch error.code {
                    case FirestoreErrorCode.unavailable.rawValue:
                        print("⚠️ Firestore unavailable (offline), using setData with merge")
                        let userData: [String: Any] = [
                            "uid": authResult.user.uid,
                            "email": authResult.user.email ?? "",
                            "displayName": authResult.user.displayName,
                            "authProvider": "google.com",
                            "lastSignInAt": FieldValue.serverTimestamp(),
                            "createdAt": FieldValue.serverTimestamp()
                        ].compactMapValues { $0 }
                        
                        try await userRef.setData(userData, merge: true)
                        print("✅ User record handled offline with merge")
                    
                    case FirestoreErrorCode.permissionDenied.rawValue:
                        print("⚠️ Firestore permission denied - API may not be enabled")
                        // Don't throw error, just log it
                        return
                    
                    default:
                        print("❌ Firestore error: \(error.localizedDescription)")
                        throw error
                    }
                } else {
                    print("❌ General error: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        // Race the timeout against the Firestore operation
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await timeoutTask.value
                }
                group.addTask {
                    try await firestoreTask.value
                }
                
                // Wait for the first task to complete
                try await group.next()
                
                // Cancel the remaining task
                group.cancelAll()
            }
        } catch {
            print("⚠️ Firestore operation failed or timed out: \(error.localizedDescription)")
            // Don't rethrow - we want authentication to succeed even if Firestore fails
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            self.isSignedIn = false
            self.errorMessage = ""
            self.isLoading = false
            
            // Reset initialization state to allow re-checking auth state
            self.isInitialized = false
            
            print("✅ Successfully signed out")
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
}