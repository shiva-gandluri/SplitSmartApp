import Foundation
import SwiftUI

/// Orchestrates session recovery UI and user interaction
@MainActor
final class SessionRecoveryManager: ObservableObject {
    @Published var hasSavedSession: Bool = false
    @Published var savedSessionSnapshot: BillSplitSessionSnapshot?
    @Published var showRecoveryBanner: Bool = false
    @Published var isCheckingForSession: Bool = false

    init() {}

    // MARK: - Session Detection

    /// Checks for saved session on app launch or navigation to home
    func checkForSavedSession() {
        print("🔍 SessionRecoveryManager: Checking for saved session...")
        isCheckingForSession = true

        // Check if session exists and is valid
        let hasSession = SessionPersistenceManager.shared.hasActiveSession()

        if hasSession {
            // Load the full session data
            savedSessionSnapshot = SessionPersistenceManager.shared.loadSession()

            if let snapshot = savedSessionSnapshot {
                hasSavedSession = true
                showRecoveryBanner = true
                print("✅ SessionRecoveryManager: Found saved session from \(snapshot.lastSavedAt)")
                print("   - Items: \(snapshot.assignedItems.count)")
                print("   - Participants: \(snapshot.participants.count)")
                print("   - Screen: \(snapshot.currentScreenIndex)")
            } else {
                print("ℹ️ SessionRecoveryManager: Session file exists but failed to load")
                hasSavedSession = false
            }
        } else {
            print("ℹ️ SessionRecoveryManager: No saved session found")
            hasSavedSession = false
        }

        isCheckingForSession = false
    }

    // MARK: - User Actions

    /// User chose to restore the saved session
    func acceptRecovery() {
        print("✅ SessionRecoveryManager: User accepted session recovery")
        showRecoveryBanner = false
        // ContentView will handle actual restoration using savedSessionSnapshot
    }

    /// User chose to discard the saved session and start fresh
    func discardRecovery() {
        print("🗑️ SessionRecoveryManager: User discarded session recovery")

        do {
            try SessionPersistenceManager.shared.clearSession()
            print("✅ SessionRecoveryManager: Cleared saved session")
        } catch {
            print("❌ SessionRecoveryManager: Failed to clear session - \(error.localizedDescription)")
        }

        hasSavedSession = false
        savedSessionSnapshot = nil
        showRecoveryBanner = false
    }

    /// Resets recovery state after successful restoration
    func reset() {
        hasSavedSession = false
        savedSessionSnapshot = nil
        showRecoveryBanner = false
        print("🔄 SessionRecoveryManager: Reset recovery state")
    }

    // MARK: - Debug Helpers

    /// Returns current session recovery state for debugging
    func debugInfo() -> String {
        return """
        SessionRecoveryManager State:
        - Has Saved Session: \(hasSavedSession)
        - Show Banner: \(showRecoveryBanner)
        - Snapshot Loaded: \(savedSessionSnapshot != nil)
        - Is Checking: \(isCheckingForSession)
        """
    }
}
