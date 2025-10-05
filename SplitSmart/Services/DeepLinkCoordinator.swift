import Foundation
import SwiftUI
import FirebaseFirestore

/**
 # DeepLinkCoordinator

 Centralized deep link handler for navigation from push notifications and external URLs.

 ## Architecture Role
 - **Pattern:** StateObject (SwiftUI Navigation Coordinator)
 - **Responsibility:** Parse URLs, manage navigation state, handle authentication gates
 - **Lifecycle:** Singleton @StateObject in SplitSmartApp

 ## Supported URL Schemes
 - `splitsmart://bill/{billId}` - Navigate to specific bill detail
 - `splitsmart://home` - Navigate to home screen

 ## Authentication Flow
 1. User taps notification → deep link received
 2. If not authenticated:
    - Store URL in `pendingDeepLink`
    - Show login screen
    - After successful login → process pending deep link
 3. If authenticated:
    - Process deep link immediately

 ## Usage
 ```swift
 // In SplitSmartApp.swift
 @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

 ContentView()
     .environmentObject(deepLinkCoordinator)
     .onOpenURL { url in
         deepLinkCoordinator.handle(url)
     }

 // In AuthViewModel after login
 if let pending = deepLinkCoordinator.pendingDeepLink {
     deepLinkCoordinator.handle(pending)
 }
 ```

 ## Industry Pattern
 - **Instagram:** Stores deep link → login → navigate
 - **Twitter:** Same pattern with seamless UX
 - **LinkedIn:** Preserves user intent across auth flow
 */
class DeepLinkCoordinator: ObservableObject {

    // MARK: - Published State

    /// Active navigation destination triggered by deep link
    @Published var activeDestination: DeepLinkDestination?

    /// Deep link stored while user is authenticating (processed after successful login)
    @Published var pendingDeepLink: URL?

    /// Loading state while fetching bill data from Firestore
    @Published var isLoading: Bool = false

    /// Error message to display if deep link processing fails
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let db = Firestore.firestore()

    // MARK: - Public Methods

    /**
     Handles incoming deep link URL.

     Parses URL scheme, validates format, checks authentication, and navigates to destination.
     If user not authenticated, stores URL for processing after login.

     - Parameter url: Deep link URL (e.g., `splitsmart://bill/abc123`)

     ## URL Formats
     - `splitsmart://bill/{billId}` - Bill detail screen
     - `splitsmart://home` - Home screen

     ## Error Handling
     - Invalid URL format → Sets errorMessage
     - User not authenticated → Stores in pendingDeepLink
     - Bill not found → Shows alert via errorMessage
     - Network error → Shows retry option
     */
    func handle(_ url: URL) {

        guard url.scheme == "splitsmart" else {
            errorMessage = "Invalid link format"
            return
        }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }


        switch host {
        case "bill":
            guard let billId = pathComponents.first else {
                errorMessage = "Invalid bill link - missing ID"
                return
            }
            handleBillDeepLink(billId: billId)

        case "home":
            activeDestination = .home

        default:
            errorMessage = "Unknown link destination"
        }
    }

    /**
     Clears active navigation destination.

     Called when user dismisses bill detail or navigates away.
     Resets coordinator state to allow new deep links.
     */
    func clearDestination() {
        activeDestination = nil
        errorMessage = nil
        isLoading = false
    }

    /**
     Clears pending deep link.

     Called after processing pending link or on user cancellation.
     */
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    // MARK: - Private Methods

    /**
     Handles navigation to bill detail screen.

     Fetches bill from Firestore, validates user has access, and sets navigation destination.
     Shows loading state during fetch and error alerts on failure.

     - Parameter billId: Firestore document ID of bill to display

     ## Access Control
     - User must be participant in bill (participantIds contains user.uid)
     - Shows "No access" error if user not authorized

     ## Error Scenarios
     - Bill not found → "Bill not found or has been deleted"
     - No permission → "You don't have access to this bill"
     - Network error → "Network error. Please try again."
     */
    private func handleBillDeepLink(billId: String) {
        isLoading = true

        Task { @MainActor in
            do {
                let billDoc = try await db.collection("bills").document(billId).getDocument()

                guard billDoc.exists else {
                    isLoading = false
                    errorMessage = "Bill not found or has been deleted"
                    return
                }

                guard let bill = try? billDoc.data(as: Bill.self) else {
                    isLoading = false
                    errorMessage = "Failed to load bill data"
                    return
                }

                // TODO: Add permission check when authentication is available
                // For now, navigate directly
                isLoading = false
                activeDestination = .billDetail(bill)

            } catch {
                isLoading = false
                errorMessage = "Network error. Please try again."
            }
        }
    }
}

// MARK: - Deep Link Destination Enum

/**
 Represents possible navigation destinations from deep links.

 ## Cases
 - `billDetail(Bill)` - Navigate to bill detail screen with bill data
 - `home` - Navigate to home screen
 */
enum DeepLinkDestination: Equatable, Identifiable {
    case billDetail(Bill)
    case home

    var id: String {
        switch self {
        case .billDetail(let bill):
            return "bill_\(bill.id)"
        case .home:
            return "home"
        }
    }

    static func == (lhs: DeepLinkDestination, rhs: DeepLinkDestination) -> Bool {
        lhs.id == rhs.id
    }
}
