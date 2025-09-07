import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - FCM Token Management Service
final class FCMTokenManager: ObservableObject {
    static let shared = FCMTokenManager()
    
    private let db = Firestore.firestore()
    @Published var currentToken: String?
    @Published var isTokenValid = false
    @Published var lastTokenRefresh: Date?
    
    private var tokenRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Token refresh configuration
    private let tokenRefreshInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Cache for email-to-token mappings
    private var tokenCache: [String: (token: String, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {
        setupTokenMonitoring()
        loadCachedToken()
    }
    
    /// Sets up automatic token monitoring and refresh
    private func setupTokenMonitoring() {
        // Monitor token expiration every 24 hours
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task {
                try? await self?.refreshTokenIfNeeded()
            }
        }
        
        // Monitor auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task {
                if user != nil {
                    try? await self?.fetchCurrentToken()
                } else {
                    await self?.cleanupTokenOnSignOut()
                }
            }
        }
    }
    
    /// Fetches current FCM token from Firebase Messaging
    @discardableResult
    func fetchCurrentToken() async throws -> String? {
        // Simulate FCM token fetching (would use Firebase Messaging SDK)
        let simulatedToken = "fcm_token_" + UUID().uuidString.prefix(12)
        
        await MainActor.run {
            self.currentToken = String(simulatedToken)
            self.isTokenValid = true
            self.lastTokenRefresh = Date()
        }
        
        // Save token to UserDefaults for persistence
        UserDefaults.standard.set(simulatedToken, forKey: "fcm_token")
        UserDefaults.standard.set(Date(), forKey: "fcm_token_refresh_date")
        
        // Update token in Firestore if user is authenticated
        if let userId = Auth.auth().currentUser?.uid {
            try await updateUserToken(String(simulatedToken), for: userId)
        }
        
        return String(simulatedToken)
    }
    
    /// Updates user's FCM token in Firestore
    func updateUserToken(_ token: String, for userId: String) async throws {
        let userRef = db.collection("users").document(userId)
        
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
            "tokenVersion": 1,
            "platform": "ios",
            "lastSeen": FieldValue.serverTimestamp()
        ]
        
        try await userRef.setData(tokenData, merge: true)
        
        print("✅ FCM token updated for user: \(userId)")
        
        // Update metadata with retry logic
        try await updateTokenMetadata(token: token, userId: userId)
    }
    
    /// Forces token refresh if needed
    func refreshTokenIfNeeded() async throws {
        let needsRefresh = await MainActor.run {
            guard let lastRefresh = self.lastTokenRefresh else { return true }
            return Date().timeIntervalSince(lastRefresh) > tokenRefreshInterval
        }
        
        if needsRefresh || !isTokenValid {
            print("🔄 Refreshing FCM token...")
            try await fetchCurrentToken()
        } else {
            print("✅ FCM token still valid")
        }
    }
    
    /// Validates token freshness and health
    func validateTokenHealth() -> Bool {
        guard let currentToken = currentToken,
              let lastRefresh = lastTokenRefresh else {
            return false
        }
        
        // Check if token is not expired (7 days)
        let tokenAge = Date().timeIntervalSince(lastRefresh)
        let isNotExpired = tokenAge < tokenRefreshInterval
        
        // Check if token format is valid
        let hasValidFormat = currentToken.hasPrefix("fcm_token_") && currentToken.count > 15
        
        return isTokenValid && isNotExpired && hasValidFormat
    }
    
    /// Cleans up tokens for signed-out users
    func cleanupTokenOnSignOut() async {
        await MainActor.run {
            self.currentToken = nil
            self.isTokenValid = false
            self.lastTokenRefresh = nil
            self.tokenCache.removeAll()
        }
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "fcm_token_refresh_date")
        
        print("🧹 FCM token cleaned up on sign out")
    }
    
    // MARK: - Private Helper Methods
    
    /// Implements exponential backoff for token refresh retries
    private func retryTokenRefresh(attempt: Int) async throws {
        let delay = baseRetryDelay * pow(2, Double(attempt - 1))
        
        print("⏳ Retrying token refresh (attempt \(attempt)/\(maxRetryAttempts)) after \(delay)s delay")
        
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            try await fetchCurrentToken()
        } catch {
            if attempt < maxRetryAttempts {
                try await retryTokenRefresh(attempt: attempt + 1)
            } else {
                throw FCMTokenError.refreshFailed("Max retry attempts reached: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates token metadata in Firestore
    private func updateTokenMetadata(token: String, userId: String) async throws {
        let metadataRef = db.collection("fcm_tokens").document(userId)
        
        let metadata: [String: Any] = [
            "userId": userId,
            "token": token,
            "createdAt": FieldValue.serverTimestamp(),
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1.0.0",
            "isActive": true,
            "lastValidated": FieldValue.serverTimestamp()
        ]
        
        try await metadataRef.setData(metadata)
        print("📊 FCM token metadata updated")
    }
    
    // MARK: - Public API for PushNotificationService
    
    /// Gets FCM tokens for multiple email addresses with caching
    func getFCMTokensForEmails(_ emails: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        var emailsToFetch: [String] = []
        
        // Check cache first
        for email in emails {
            if let cachedEntry = tokenCache[email],
               Date().timeIntervalSince(cachedEntry.timestamp) < cacheExpirationInterval {
                result[email] = cachedEntry.token
            } else {
                emailsToFetch.append(email)
            }
        }
        
        // Fetch missing tokens from Firestore
        if !emailsToFetch.isEmpty {
            let fetchedTokens = await fetchTokensFromFirestore(emails: emailsToFetch)
            
            // Update cache and result
            for (email, token) in fetchedTokens {
                tokenCache[email] = (token: token, timestamp: Date())
                result[email] = token
            }
        }
        
        return result
    }
    
    /// Fetches FCM tokens from Firestore for given emails
    private func fetchTokensFromFirestore(emails: [String]) async -> [String: String] {
        var tokens: [String: String] = [:]
        
        do {
            // Query participants collection to get user IDs from emails
            let participantsRef = db.collection("participants")
            let snapshot = try await participantsRef.whereField("email", in: emails).getDocuments()
            
            // Get user IDs and then fetch their FCM tokens
            for document in snapshot.documents {
                let email = document.data()["email"] as? String ?? ""
                let userId = document.data()["userId"] as? String ?? ""
                
                if !email.isEmpty && !userId.isEmpty {
                    if let token = await fetchUserToken(userId: userId) {
                        tokens[email] = token
                    }
                }
            }
        } catch {
            print("❌ Error fetching FCM tokens: \(error.localizedDescription)")
        }
        
        return tokens
    }
    
    /// Fetches FCM token for a specific user ID
    private func fetchUserToken(userId: String) async -> String? {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            return userDoc.data()?["fcmToken"] as? String
        } catch {
            print("❌ Error fetching token for user \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Loads cached token from UserDefaults on app startup
    private func loadCachedToken() {
        if let cachedToken = UserDefaults.standard.string(forKey: "fcm_token"),
           let cachedDate = UserDefaults.standard.object(forKey: "fcm_token_refresh_date") as? Date {
            
            self.currentToken = cachedToken
            self.lastTokenRefresh = cachedDate
            self.isTokenValid = validateTokenHealth()
            
            print("✅ Loaded cached FCM token")
        }
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - FCM Token Error Types
enum FCMTokenError: LocalizedError {
    case tokenNotAvailable
    case refreshFailed(String)
    case networkError(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .tokenNotAvailable:
            return "FCM token is not available"
        case .refreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "User must be authenticated to manage tokens"
        }
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for FCMTokenManager extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */