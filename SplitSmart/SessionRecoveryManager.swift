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
                // Validate session is actually incomplete and has meaningful data
                // sessionState is stored as String (SessionState.rawValue)
                let isIncomplete = snapshot.sessionState != "complete" && snapshot.sessionState != "home"
                let hasMeaningfulData = !snapshot.assignedItems.isEmpty || !snapshot.participants.isEmpty

                if isIncomplete && hasMeaningfulData {
                    hasSavedSession = true
                    showRecoveryBanner = true
                    print("✅ SessionRecoveryManager: Found valid incomplete session from \(snapshot.lastSavedAt)")
                    print("   - Items: \(snapshot.assignedItems.count)")
                    print("   - Participants: \(snapshot.participants.count)")
                    print("   - Screen: \(snapshot.currentScreenIndex)")
                    print("   - State: \(snapshot.sessionState)")
                } else {
                    print("⏭️ SessionRecoveryManager: Session found but not valid for recovery")
                    print("   - State: \(snapshot.sessionState) (must be scanning/assigning/reviewing)")
                    print("   - Items: \(snapshot.assignedItems.count)")
                    print("   - Participants: \(snapshot.participants.count)")

                    // Clear invalid session automatically
                    do {
                        try SessionPersistenceManager.shared.clearSession()
                        print("🗑️ SessionRecoveryManager: Auto-cleared invalid session")
                    } catch {
                        print("⚠️ SessionRecoveryManager: Failed to clear invalid session - \(error.localizedDescription)")
                    }

                    hasSavedSession = false
                    showRecoveryBanner = false
                }
            } else {
                print("ℹ️ SessionRecoveryManager: Session file exists but failed to load")
                hasSavedSession = false
                showRecoveryBanner = false
            }
        } else {
            print("ℹ️ SessionRecoveryManager: No saved session found")
            hasSavedSession = false
            showRecoveryBanner = false
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
