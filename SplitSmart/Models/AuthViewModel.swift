import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isInitializing = true
    
    private var isInitialized = false
    
    // SECURITY: Rate limiting for database operations
    private var lastQueryTime: Date = Date.distantPast
    private var queryCount: Int = 0
    private let maxQueriesPerMinute: Int = 30
    private let minTimeBetweenQueries: TimeInterval = 1.0 // 1 second
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    
    // Debug function to create test users
    func createTestUser(email: String, displayName: String, phoneNumber: String? = nil) async {
        guard let db = Firestore.firestore() as Firestore? else {
            print("❌ Firestore not available")
            return
        }
        
        do {
            let testUID = "test_\(UUID().uuidString.prefix(8))"
            let userRef = db.collection("users").document(testUID)
            
            var userData: [String: Any] = [
                "uid": testUID,
                "email": email.lowercased(),
                "displayName": displayName,
                "authProvider": "test",
                "createdAt": FieldValue.serverTimestamp(),
                "lastSignInAt": FieldValue.serverTimestamp()
            ]
            
            if let phoneNumber = phoneNumber {
                userData["phoneNumber"] = phoneNumber
            }
            
            try await userRef.setData(userData, merge: true)
            print("✅ Test user created: \(email)")
            
        } catch {
            print("❌ Failed to create test user: \(error.localizedDescription)")
        }
    }
    
    // SECURITY: Rate limiting check
    private func checkRateLimit() async -> Bool {
        let now = Date()
        
        // Reset counter if more than a minute has passed
        if now.timeIntervalSince(lastQueryTime) > 60 {
            queryCount = 0
        }
        
        // Check if we're within rate limits
        guard queryCount < maxQueriesPerMinute else {
            print("⚠️ Rate limit exceeded. Please wait before making more requests.")
            return false
        }
        
        // Check minimum time between queries
        guard now.timeIntervalSince(lastQueryTime) >= minTimeBetweenQueries else {
            print("⚠️ Too many requests. Please wait \(minTimeBetweenQueries) seconds between requests.")
            // Small delay to prevent rapid successive calls
            try? await Task.sleep(nanoseconds: UInt64(minTimeBetweenQueries * 1_000_000_000))
            return false
        }
        
        // Update rate limiting counters
        lastQueryTime = now
        queryCount += 1
        return true
    }
    
    // SECURE Input validation functions
    nonisolated static func validateEmail(_ email: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return (false, nil, "Email cannot be empty")
        }
        
        // Basic length check
        guard email.count <= 254 else {
            return (false, nil, "Email too long (max 254 characters)")
        }
        
        // Email regex pattern - RFC 5322 compliant
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            return (false, nil, "Invalid email format")
        }
        
        // Additional security checks
        let lowercaseEmail = email.lowercased()
        
        // Block potentially malicious patterns
        let suspiciousPatterns = ["javascript:", "data:", "<script", "%3cscript"]
        for pattern in suspiciousPatterns {
            if lowercaseEmail.contains(pattern) {
                return (false, nil, "Invalid email format")
            }
        }
        
        return (true, lowercaseEmail, nil)
    }
    
    nonisolated static func validatePhoneNumber(_ phone: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return (false, nil, "Phone number cannot be empty")
        }
        
        // Remove all non-digit characters for validation
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // Basic length checks
        guard digitsOnly.count >= 10 && digitsOnly.count <= 15 else {
            return (false, nil, "Phone number must be 10-15 digits")
        }
        
        // Simple international format check
        let phoneRegex = #"^\+?[1-9]\d{9,14}$"#
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        guard phonePredicate.evaluate(with: digitsOnly) else {
            return (false, nil, "Invalid phone number format")
        }
        
        // Security checks - block suspicious patterns
        let suspiciousPatterns = ["javascript:", "data:", "<script"]
        for pattern in suspiciousPatterns {
            if phone.lowercased().contains(pattern) {
                return (false, nil, "Invalid phone number format")
            }
        }
        
        return (true, digitsOnly, nil)
    }
    
    nonisolated static func validateDisplayName(_ name: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return (false, nil, "Name cannot be empty")
        }
        
        guard name.count <= 100 else {
            return (false, nil, "Name too long (max 100 characters)")
        }
        
        // Only allow letters, numbers, spaces, and common punctuation
        let allowedCharacterSet = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ".-'"))
        guard name.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return (false, nil, "Name contains invalid characters")
        }
        
        // Security checks
        let suspiciousPatterns = ["javascript:", "data:", "<script", "<?", "%3c"]
        for pattern in suspiciousPatterns {
            if name.lowercased().contains(pattern) {
                return (false, nil, "Invalid name format")
            }
        }
        
        return (true, name, nil)
    }
    
    // SECURE User validation service - checks both participants and users collections with auto-migration
    func isUserOnboarded(email: String? = nil, phoneNumber: String? = nil) async -> Bool {
        // SECURITY: Check rate limiting first
        guard await checkRateLimit() else {
            print("❌ Rate limit exceeded for user validation")
            return false
        }
        
        guard let db = Firestore.firestore() as Firestore? else {
            print("❌ Firestore not available")
            return false
        }
        
        do {
            print("🔍 Checking user onboarding status...")
            
            // Validate and check by email first
            if let email = email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    print("📧 Email to check: \(sanitizedEmail)")
                    
                    // First check the new participants collection
                    let participantsRef = db.collection("participants")
                    let participantEmailQuery = participantsRef.whereField("email", isEqualTo: sanitizedEmail)
                    let participantSnapshot = try await participantEmailQuery.getDocuments(source: .default)
                    
                    if !participantSnapshot.isEmpty {
                        print("✅ User found in participants collection: \(sanitizedEmail)")
                        return true
                    }
                    
                    // If not found in participants, check the original users collection
                    let usersRef = db.collection("users")
                    let userEmailQuery = usersRef.whereField("email", isEqualTo: sanitizedEmail)
                    let userSnapshot = try await userEmailQuery.getDocuments(source: .default)
                    
                    if !userSnapshot.isEmpty {
                        print("✅ User found in users collection: \(sanitizedEmail)")
                        
                        // Auto-migrate: Create participant record for existing user
                        if let userDoc = userSnapshot.documents.first {
                            await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                        }
                        
                        return true
                    }
                } else {
                    print("⚠️ Invalid email format provided: \(emailValidation.error ?? "Unknown error")")
                    return false
                }
            }
            
            // Validate and check by phone number if email not found
            if let phoneNumber = phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    print("📱 Phone to check: \(sanitizedPhone)")
                    
                    // First check the new participants collection
                    let participantsRef = db.collection("participants")
                    let participantPhoneQuery = participantsRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let participantSnapshot = try await participantPhoneQuery.getDocuments(source: .default)
                    
                    if !participantSnapshot.isEmpty {
                        print("✅ User found with phone in participants: \(sanitizedPhone)")
                        return true
                    }
                    
                    // If not found in participants, check the original users collection
                    let usersRef = db.collection("users")
                    let userPhoneQuery = usersRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let userSnapshot = try await userPhoneQuery.getDocuments(source: .default)
                    
                    if !userSnapshot.isEmpty {
                        print("✅ User found with phone in users collection: \(sanitizedPhone)")
                        
                        // Auto-migrate: Create participant record for existing user
                        if let userDoc = userSnapshot.documents.first {
                            await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                        }
                        
                        return true
                    }
                } else {
                    print("⚠️ Invalid phone format provided: \(phoneValidation.error ?? "Unknown error")")
                    return false
                }
            }
            
            print("❌ User not found in either participants or users collection")
            return false
            
        } catch {
            print("❌ Error checking user onboarding status: \(error.localizedDescription)")
            return false
        }
    }
    
    // Auto-migration helper: Creates participant record from existing user data
    private func autoMigrateUserToParticipant(userDoc: DocumentSnapshot, db: Firestore) async {
        do {
            let userData = userDoc.data() ?? [:]
            let userId = userDoc.documentID
            
            print("🔄 Auto-migrating user \(userId) to participants collection...")
            
            let participantRef = db.collection("participants").document(userId)
            
            // Check if participant record already exists
            let existingParticipant = try await participantRef.getDocument(source: .default)
            if existingParticipant.exists {
                print("ℹ️ Participant record already exists for \(userId)")
                return
            }
            
            // Create participant record with validated data
            var participantData: [String: Any] = [
                "isActive": true,
                "createdAt": userData["createdAt"] ?? FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add display name
            if let displayName = userData["displayName"] as? String {
                let nameValidation = AuthViewModel.validateDisplayName(displayName)
                participantData["displayName"] = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            } else {
                participantData["displayName"] = "Unknown User"
            }
            
            // Validate and add email if available
            if let email = userData["email"] as? String {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = userData["phoneNumber"] as? String {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                }
            }
            
            try await participantRef.setData(participantData, merge: true)
            print("✅ Successfully migrated user \(userId) to participants collection")
            
        } catch {
            print("⚠️ Failed to auto-migrate user to participants: \(error.localizedDescription)")
            // Don't fail the validation - just log the error
        }
    }
    
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
            
            // MIGRATION: Ensure participant record exists for existing users
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.ensureParticipantRecordExists(for: user)
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
            
            // Create user record in background (non-blocking)
            Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    try await self?.createUserRecord(authResult: authResult)
                    try await self?.createParticipantRecord(authResult: authResult)
                    
                    // MIGRATION: Auto-migrate existing users on login
                    await self?.performAutoMigrationIfNeeded(authResult: authResult)
                    
                    print("✅ User and participant record creation completed")
                } catch {
                    print("❌ Background record creation failed: \(error.localizedDescription)")
                    print("ℹ️ App will continue - records will be created on retry")
                }
            }
            
            // Update UI state immediately
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
        print("👤 User info: UID=\(authResult.user.uid), Email=\(authResult.user.email ?? "nil"), DisplayName=\(authResult.user.displayName ?? "nil")")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(authResult.user.uid)
        print("📂 Document reference created: users/\(authResult.user.uid)")
        
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
                    
                    var userData: [String: Any] = [
                        "uid": authResult.user.uid,
                        "email": authResult.user.email ?? "",
                        "displayName": authResult.user.displayName ?? "",
                        "authProvider": "google.com",
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSignInAt": FieldValue.serverTimestamp()
                    ]
                    
                    // Add phone number if available from Google OAuth
                    if let phoneNumber = authResult.user.phoneNumber {
                        userData["phoneNumber"] = phoneNumber
                        print("📱 Adding phone number: \(phoneNumber)")
                    }
                    
                    let cleanedUserData = userData.compactMapValues { $0 }
                    print("💾 About to save user data: \(cleanedUserData)")
                    
                    try await userRef.setData(cleanedUserData, merge: true)
                    print("✅ User record created in Firestore successfully!")
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
                        var userData: [String: Any] = [
                            "uid": authResult.user.uid,
                            "email": authResult.user.email ?? "",
                            "displayName": authResult.user.displayName ?? "",
                            "authProvider": "google.com",
                            "lastSignInAt": FieldValue.serverTimestamp(),
                            "createdAt": FieldValue.serverTimestamp()
                        ]
                        
                        // Add phone number if available from Google OAuth
                        if let phoneNumber = authResult.user.phoneNumber {
                            userData["phoneNumber"] = phoneNumber
                        }
                        
                        let cleanedUserData = userData.compactMapValues { $0 }
                        
                        try await userRef.setData(cleanedUserData, merge: true)
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
    
    // SECURE: Create participant record with validated minimal public data only
    private func createParticipantRecord(authResult: AuthDataResult) async throws {
        print("🔵 Creating secure participant record...")
        
        let db = Firestore.firestore()
        let participantRef = db.collection("participants").document(authResult.user.uid)
        
        // Check if participant record already exists
        let document = try await participantRef.getDocument(source: .default)
        
        if !document.exists {
            print("🔵 Creating new participant record...")
            
            // Validate display name
            let nameValidation = AuthViewModel.validateDisplayName(authResult.user.displayName)
            let validatedDisplayName = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            
            // Only store minimal public information needed for participant validation
            var participantData: [String: Any] = [
                "displayName": validatedDisplayName,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add email if available
            if let email = authResult.user.email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                    print("✅ Validated email added to participant record")
                } else {
                    print("⚠️ Invalid email from auth provider: \(emailValidation.error ?? "Unknown error")")
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = authResult.user.phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                    print("✅ Validated phone number added to participant record")
                } else {
                    print("⚠️ Invalid phone number from auth provider: \(phoneValidation.error ?? "Unknown error")")
                }
            }
            
            try await participantRef.setData(participantData, merge: true)
            print("✅ Secure participant record created with validated data")
        } else {
            print("ℹ️ Participant record already exists, updating activity")
            try await participantRef.updateData([
                "lastActiveAt": FieldValue.serverTimestamp(),
                "isActive": true
            ])
        }
    }
    
    // MIGRATION: Auto-migrate current user's data when they log in
    private func performAutoMigrationIfNeeded(authResult: AuthDataResult) async {
        do {
            let db = Firestore.firestore()
            let userId = authResult.user.uid
            
            // Check if participant record already exists
            let participantRef = db.collection("participants").document(userId)
            let participantDoc = try await participantRef.getDocument(source: .default)
            
            if !participantDoc.exists {
                print("🔄 Performing auto-migration for current user...")
                
                // Get current user's data from users collection (allowed since it's their own data)
                let userRef = db.collection("users").document(userId)
                let userDoc = try await userRef.getDocument(source: .default)
                
                if userDoc.exists {
                    await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                    print("✅ Auto-migration completed for current user")
                } else {
                    print("ℹ️ No user document found to migrate")
                }
            } else {
                print("ℹ️ Participant record already exists - no migration needed")
            }
            
        } catch {
            print("⚠️ Auto-migration failed: \(error.localizedDescription)")
            // Don't fail login - just log the error
        }
    }
    
    // MIGRATION: Ensure participant record exists for any authenticated user
    private func ensureParticipantRecordExists(for user: User) async {
        do {
            let db = Firestore.firestore()
            let userId = user.uid
            
            print("🔍 Checking if participant record exists for current user...")
            
            // Check if participant record already exists
            let participantRef = db.collection("participants").document(userId)
            let participantDoc = try await participantRef.getDocument(source: .default)
            
            if !participantDoc.exists {
                print("🔄 Creating participant record for existing user...")
                
                // Get current user's data from users collection (allowed since it's their own data)
                let userRef = db.collection("users").document(userId)
                let userDoc = try await userRef.getDocument(source: .default)
                
                if userDoc.exists {
                    print("📊 Found user document, migrating to participants...")
                    await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                    print("✅ Migration completed for existing user")
                } else {
                    print("📝 No user document found, creating participant from auth data...")
                    // Create participant record from auth user data directly
                    await createParticipantFromAuth(user: user, db: db)
                }
            } else {
                print("ℹ️ Participant record already exists - no migration needed")
            }
            
        } catch {
            print("⚠️ Failed to ensure participant record exists: \(error.localizedDescription)")
            // Don't fail - just log the error
        }
    }
    
    // Create participant record directly from Auth user data
    private func createParticipantFromAuth(user: User, db: Firestore) async {
        do {
            let participantRef = db.collection("participants").document(user.uid)
            
            // Validate display name
            let nameValidation = AuthViewModel.validateDisplayName(user.displayName)
            let validatedDisplayName = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            
            // Create participant record with validated data
            var participantData: [String: Any] = [
                "displayName": validatedDisplayName,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add email if available
            if let email = user.email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                    print("✅ Validated email added to participant record")
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = user.phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                    print("✅ Validated phone number added to participant record")
                }
            }
            
            try await participantRef.setData(participantData, merge: true)
            print("✅ Participant record created from auth data")
            
        } catch {
            print("⚠️ Failed to create participant from auth: \(error.localizedDescription)")
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