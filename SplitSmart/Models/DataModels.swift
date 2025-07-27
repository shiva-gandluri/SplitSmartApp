import SwiftUI
import Vision
import UIKit
import NaturalLanguage
import FirebaseFirestore

// MARK: - Currency Utilities
extension Double {
    /// Rounds a currency value to 2 decimal places with proper rounding
    var currencyRounded: Double {
        return (self * 100).rounded() / 100
    }
    
    /// Safely adds two currency values with proper rounding
    func currencyAdd(_ other: Double) -> Double {
        return (self + other).currencyRounded
    }
    
    /// Safely divides currency value by count with proper rounding
    func currencyDivide(by count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        return (self / Double(count)).currencyRounded
    }
    
    /// Smart distribution of currency among participants ensuring total matches exactly
    /// Example: $8.99 / 2 = [$4.49, $4.50] instead of [$4.495, $4.495]
    static func smartDistribute(total: Double, among count: Int) -> [Double] {
        guard count > 0 else { return [] }
        
        let baseAmount = (total / Double(count)).currencyRounded
        let totalBasic = baseAmount * Double(count)
        let remainder = (total - totalBasic).currencyRounded
        
        var distribution = Array(repeating: baseAmount, count: count)
        
        // Distribute remainder cents to first participants
        let remainderCents = Int((remainder * 100).rounded())
        for i in 0..<min(abs(remainderCents), count) {
            distribution[i] = distribution[i].currencyAdd(remainderCents > 0 ? 0.01 : -0.01)
        }
        
        return distribution
    }
}

// MARK: - Data Models

// MARK: - Error Types
enum OCRError: Error {
    case apiError(String)
    case parseError(String)
    case networkError(String)
}

// MARK: - OCR Models
struct OCRResult {
    let rawText: String
    let parsedItems: [ReceiptItem] // Will be empty initially - users add manually
    let identifiedTotal: Double?
    let suggestedAmounts: [Double] // Potential item prices for quick selection
    let confidence: Float
    let processingTime: TimeInterval
}

enum ConfidenceLevel {
    case high       // Exact match found in OCR text
    case medium     // Part of close combination
    case low        // Approximated or uncertain
    case placeholder // User needs to fill in
}

struct ReceiptItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var price: Double
    var confidence: ConfidenceLevel = .high
    var isEditable: Bool = true
    
    // Store original detected values for confidence display
    let originalDetectedName: String?
    let originalDetectedPrice: Double?
    
    init(name: String, price: Double, confidence: ConfidenceLevel = .high, originalDetectedName: String? = nil, originalDetectedPrice: Double? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = price
        self.confidence = confidence
        self.originalDetectedName = originalDetectedName
        self.originalDetectedPrice = originalDetectedPrice
    }
}

struct ReceiptAnalysis {
    let tax: Double
    let tip: Double  
    let total: Double
    let itemCount: Int
}

// MARK: - Shared Transaction Models
struct UITransaction: Identifiable {
    let id = UUID()
    let personName: String
    let amount: Double
    let description: String
}

struct UIPersonDebt: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let color: Color
}

// MARK: - Assign Screen Models
struct UIParticipant: Identifiable, Hashable {
    let id: Int
    let name: String
    let color: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UIParticipant, rhs: UIParticipant) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Transaction Contact Models (Splitwise-style)
struct TransactionContact: Identifiable, Codable {
    let id: String                    // Contact ID in our system
    let contactUserId: String?        // Reference to global participants collection (if registered)
    let displayName: String           // How this user knows them
    let email: String
    let phoneNumber: String?
    let lastTransactionAt: Date
    let totalTransactions: Int
    let createdAt: Date
    let updatedAt: Date
    let nickname: String?             // Optional custom nickname
    
    init(displayName: String, email: String, phoneNumber: String? = nil, contactUserId: String? = nil, nickname: String? = nil) {
        self.id = UUID().uuidString
        self.contactUserId = contactUserId
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.lastTransactionAt = Date()
        self.totalTransactions = 1
        self.createdAt = Date()
        self.updatedAt = Date()
        self.nickname = nickname
    }
}

struct ContactValidationResult {
    let isValid: Bool
    let error: String?
    let contact: TransactionContact?
}

struct UIItem: Identifiable {
    let id: Int
    var name: String
    var price: Double
    var assignedTo: Int? // Legacy: single participant assignment (for backward compatibility)
    var assignedToParticipants: Set<Int> // New: multiple participants per item
    var confidence: ConfidenceLevel
    
    // Store original detected values for confidence display
    let originalDetectedName: String?
    let originalDetectedPrice: Double?
    
    // Computed property to get the cost per assigned participant (simple division, for display)
    var costPerParticipant: Double {
        let participantCount = assignedToParticipants.isEmpty ? 1 : assignedToParticipants.count
        return price.currencyDivide(by: participantCount)
    }
    
    // Get the exact cost for a specific participant using smart distribution
    func getCostForParticipant(participantId: Int) -> Double {
        guard assignedToParticipants.contains(participantId) else { return 0.0 }
        
        let participantIds = Array(assignedToParticipants).sorted()
        let distribution = Double.smartDistribute(total: price, among: participantIds.count)
        
        if let index = participantIds.firstIndex(of: participantId) {
            return distribution[index]
        }
        
        return 0.0
    }
    
    // Initialize with multiple participants support
    init(id: Int, name: String, price: Double, assignedTo: Int? = nil, assignedToParticipants: Set<Int> = [], confidence: ConfidenceLevel = .high, originalDetectedName: String? = nil, originalDetectedPrice: Double? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.assignedTo = assignedTo
        self.assignedToParticipants = assignedToParticipants
        self.confidence = confidence
        self.originalDetectedName = originalDetectedName
        self.originalDetectedPrice = originalDetectedPrice
    }
}

// MARK: - Summary Screen Models
struct UISummary {
    let restaurant: String
    let date: String
    let total: Double
    let paidBy: String
    let participants: [UISummaryParticipant]
    let breakdown: [UIBreakdown]
}

struct UISummaryParticipant: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let owes: Double
    let gets: Double
}

struct UIBreakdown: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let items: [UIBreakdownItem]
}

struct UIBreakdownItem {
    let name: String
    let price: Double
}

// MARK: - Bill Settlement Data Models

import FirebaseFirestore
import FirebaseAuth
// TODO: Add FirebaseMessaging via Xcode Package Dependencies
// import FirebaseMessaging

struct Bill: Codable, Identifiable {
    let id: String
    let paidBy: String // userID who paid
    let paidByDisplayName: String // Snapshot for UI
    let paidByEmail: String // Snapshot for notifications
    let billName: String? // Custom name or default description (optional for backward compatibility)
    let totalAmount: Double // Always matches sum of items
    let currency: String
    let date: Timestamp
    let createdAt: Timestamp
    let items: [BillItem]
    let participants: [BillParticipant]
    let participantIds: [String] // Flattened array for efficient Firestore querying
    
    // Audit trail
    let createdBy: String // userID who created bill
    let lastModifiedBy: String?
    let lastModifiedAt: Timestamp?
    
    // Financial reconciliation
    let calculatedTotals: [String: Double] // userID: amount owed to paidBy
    let roundingAdjustments: [String: Double] // Track penny distributions
    
    init(id: String = UUID().uuidString,
         paidBy: String,
         paidByDisplayName: String,
         paidByEmail: String,
         billName: String?,
         totalAmount: Double,
         currency: String = "USD",
         date: Timestamp = Timestamp(),
         items: [BillItem],
         participants: [BillParticipant],
         createdBy: String,
         calculatedTotals: [String: Double],
         roundingAdjustments: [String: Double] = [:]) {
        self.id = id
        self.paidBy = paidBy
        self.paidByDisplayName = paidByDisplayName
        self.paidByEmail = paidByEmail
        self.billName = billName
        self.totalAmount = totalAmount
        self.currency = currency
        self.date = date
        self.createdAt = Timestamp()
        self.items = items
        self.participants = participants
        self.participantIds = participants.map { $0.id } // Flatten for querying
        self.createdBy = createdBy
        self.lastModifiedBy = nil
        self.lastModifiedAt = nil
        self.calculatedTotals = calculatedTotals
        self.roundingAdjustments = roundingAdjustments
    }
    
    /// Returns the display name for the bill (custom name or default based on items)
    var displayName: String {
        if let billName = billName, !billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return billName
        } else {
            return items.count == 1 ? items[0].name : "\(items.count) items"
        }
    }
}

struct BillItem: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let participantIDs: [String] // Array of userIDs who split this item
    
    init(name: String, price: Double, participantIDs: [String]) {
        self.id = UUID().uuidString
        self.name = name
        self.price = price
        self.participantIDs = participantIDs
    }
}

struct BillParticipant: Codable, Identifiable {
    let id: String // This will be the userID
    let displayName: String // Snapshot for UI
    let email: String // Snapshot for notifications
    let isActive: Bool // Track if user still exists
    
    init(userID: String, displayName: String, email: String, isActive: Bool = true) {
        self.id = userID
        self.displayName = displayName
        self.email = email
        self.isActive = isActive
    }
}

// BillStatus enum removed - bills are simply created and exist without status

// MARK: - Bill Service for Firebase Operations

class BillService: ObservableObject {
    private let db = Firestore.firestore()
    
    /// Creates a new bill in Firestore with atomic transactions
    func createBill(from session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws -> Bill {
        print("🔵 Starting Firebase bill creation...")
        
        // Validate session readiness
        guard session.isReadyForBillCreation else {
            throw BillCreationError.sessionNotReady
        }
        
        guard let currentUser = await MainActor.run { authViewModel.user },
              let paidByID = session.paidByParticipantID,
              let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) else {
            throw BillCreationError.invalidUser
        }
        
        // Convert session data to Bill format
        let billItems = session.assignedItems.map { item in
            BillItem(
                name: item.name,
                price: item.price,
                participantIDs: Array(item.assignedToParticipants).map { String($0) }
            )
        }
        
        // Get participant details from contacts and current user
        var billParticipants: [BillParticipant] = []
        
        // Add current user as participant
        let currentUserParticipant = BillParticipant(
            userID: currentUser.uid,
            displayName: currentUser.displayName ?? "You",
            email: currentUser.email ?? "unknown@example.com"
        )
        billParticipants.append(currentUserParticipant)
        
        // Add other participants from transaction contacts
        for participant in session.participants where participant.name != "You" {
            if let contact = contactsManager.transactionContacts.first(where: { 
                $0.displayName.lowercased() == participant.name.lowercased() 
            }) {
                // For now, use a consistent ID based on email for cross-user bill visibility
                // TODO: Implement proper user lookup by email in Phase 3
                let participantUserID = contact.contactUserId ?? "email_\(contact.email.lowercased().replacingOccurrences(of: "@", with: "_at_").replacingOccurrences(of: ".", with: "_"))"
                
                let billParticipant = BillParticipant(
                    userID: participantUserID,
                    displayName: contact.displayName,
                    email: contact.email
                )
                billParticipants.append(billParticipant)
                
                print("🔍 Added participant: \(contact.displayName) with ID: \(participantUserID)")
            }
        }
        
        // Calculate debts using the session's logic
        let calculatedDebts = session.individualDebts
        
        // Get payer details
        let paidByEmail: String
        if paidByParticipant.name == "You" {
            paidByEmail = currentUser.email ?? "unknown@example.com"
        } else if let contact = contactsManager.transactionContacts.first(where: { 
            $0.displayName.lowercased() == paidByParticipant.name.lowercased() 
        }) {
            paidByEmail = contact.email
        } else {
            paidByEmail = "unknown@example.com"
        }
        
        // Determine bill name (use custom name if provided, otherwise default)
        let finalBillName: String? = session.billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? nil  // Will use computed displayName
            : session.billName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create Bill object
        let bill = Bill(
            paidBy: paidByParticipant.name == "You" ? currentUser.uid : "unknown_\(paidByID)",
            paidByDisplayName: paidByParticipant.name,
            paidByEmail: paidByEmail,
            billName: finalBillName,
            totalAmount: session.totalAmount,
            items: billItems,
            participants: billParticipants,
            createdBy: currentUser.uid,
            calculatedTotals: calculatedDebts
        )
        
        // Validate bill totals
        guard BillCalculator.validateBillTotals(bill: bill) else {
            throw BillCreationError.invalidTotals
        }
        
        // Save to Firestore with atomic transaction
        try await saveBillToFirestore(bill: bill)
        
        print("✅ Bill created successfully with ID: \(bill.id)")
        
        // Send push notifications to participants (async, don't block UI)
        Task {
            await PushNotificationService.shared.sendBillNotificationToParticipants(bill: bill)
        }
        
        return bill
    }
    
    /// Saves bill to Firestore using atomic batch operations
    private func saveBillToFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Save bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update only the current user's record (bill creator)
        // Other participants will see bills via the bills collection query
        let currentUserRef = db.collection("users").document(bill.createdBy)
        batch.updateData([
            "billIds": FieldValue.arrayUnion([bill.id]),
            "lastBillUpdate": FieldValue.serverTimestamp()
        ], forDocument: currentUserRef)
        
        // Commit batch operation
        try await batch.commit()
        print("✅ Bill batch operation completed successfully")
    }
}

// MARK: - Bill Manager for Real-time Updates

class BillManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var userBills: [Bill] = []
    @Published var userBalance: UserBalance = UserBalance()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentUserId: String?
    private var billsListener: ListenerRegistration?
    
    init() {}
    
    func setCurrentUser(_ userId: String) {
        // Clear existing data if switching users
        if let currentUser = self.currentUserId, currentUser != userId {
            print("🔄 Switching bill manager users from \(currentUser) to \(userId)")
            billsListener?.remove()
            billsListener = nil
            self.userBills = []
            self.userBalance = UserBalance()
            self.errorMessage = nil
        }
        
        self.currentUserId = userId
        loadUserBills()
    }
    
    func clearCurrentUser() {
        print("🧹 Clearing BillManager data on logout")
        billsListener?.remove()
        billsListener = nil
        self.currentUserId = nil
        self.userBills = []
        self.userBalance = UserBalance()
        self.errorMessage = nil
        self.isLoading = false
    }
    
    /// Sets up real-time listener for bills where user is involved
    private func loadUserBills() {
        guard let userId = currentUserId else { return }
        
        billsListener?.remove()
        isLoading = true
        
        print("📡 Setting up real-time bill listener for user: \(userId)")
        
        // Listen for bills where user is involved as participant
        billsListener = db.collection("bills")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ Failed to load bills: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load bills: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No bills found for user")
                        self?.userBills = []
                        self?.calculateUserBalance()
                        return
                    }
                    
                    print("📊 Found \(documents.count) bill documents for user")
                    let bills = documents.compactMap { doc in
                        do {
                            let bill = try doc.data(as: Bill.self)
                            print("✅ Loaded bill: \(bill.id) - $\(bill.totalAmount)")
                            return bill
                        } catch {
                            print("❌ Failed to decode bill document \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    self?.userBills = bills
                    self?.calculateUserBalance()
                    print("📋 Total bills loaded: \(bills.count)")
                }
            }
    }
    
    /// Calculates user's current balance from all bills
    private func calculateUserBalance() {
        guard let userId = currentUserId else { 
            print("❌ calculateUserBalance: No current user ID")
            return 
        }
        
        print("🧮 Calculating balance for user: \(userId)")
        print("🧮 Processing \(userBills.count) bills")
        
        var totalOwed: Double = 0.0
        var totalOwedTo: Double = 0.0
        var activeBills: [String] = []
        
        for bill in userBills {
            print("🧮 Processing bill \(bill.id): paidBy=\(bill.paidBy), total=\(bill.totalAmount)")
            print("🧮 Bill calculatedTotals: \(bill.calculatedTotals)")
            
            activeBills.append(bill.id)
            
            // If user is the payer, they are owed money
            if bill.paidBy == userId {
                    print("🧮 User is the payer for this bill")
                    for (participantID, amount) in bill.calculatedTotals {
                        if participantID != userId && amount > 0.01 {
                            totalOwedTo += amount
                            print("🧮 Participant \(participantID) owes user $\(amount)")
                        }
                    }
                } else {
                    print("🧮 User is NOT the payer for this bill")
                    // If user is a participant who owes money
                    if let amountOwed = bill.calculatedTotals[userId], amountOwed > 0.01 {
                        totalOwed += amountOwed
                        print("🧮 User owes $\(amountOwed) for this bill")
                    } else {
                        print("🧮 User not found in calculatedTotals or owes $0")
                    }
                }
        }
        
        userBalance = UserBalance(
            totalOwed: totalOwed,
            totalOwedTo: totalOwedTo,
            activeBillIds: activeBills
        )
        
        print("💰 Updated user balance - Owes: $\(totalOwed), Owed: $\(totalOwedTo)")
        print("💰 Active bills: \(activeBills)")
    }
    
    /// Gets net balances with all users (positive = they owe you, negative = you owe them)
    func getNetBalances() -> [UIPersonDebt] {
        guard let userId = currentUserId else { 
            print("❌ getNetBalances: No current user ID")
            return [] 
        }
        
        print("🧮 Calculating net balances for user: \(userId)")
        
        var balances: [String: Double] = [:] // participantID -> net amount (+ they owe you, - you owe them)
        var participantInfo: [String: (name: String, email: String)] = [:]
        
        // Helper function to normalize participant IDs (always use consistent email-based format)
        func normalizeParticipantID(_ id: String, displayName: String, email: String) -> String {
            // Always normalize to email-based format for consistency
            let normalizedEmail = email.lowercased()
                .replacingOccurrences(of: "@", with: "_at_")
                .replacingOccurrences(of: ".", with: "_")
            
            // Use email_prefix format consistently
            return "email_\(normalizedEmail)"
        }
        
        for bill in userBills {
            print("🧮 Processing bill \(bill.id) for net balance")
            print("🧮 Bill paidBy: \(bill.paidBy), current user: \(userId)")
            print("🧮 Bill calculatedTotals: \(bill.calculatedTotals)")
            
            // Process all bills (no status filtering)
            if bill.paidBy == userId {
                print("🧮 User paid - others owe user")
                // User paid - others owe them (positive balance)
                for (sessionParticipantID, amount) in bill.calculatedTotals {
                    if sessionParticipantID != "1" && amount > 0.01 {
                        // Map session participant ID to actual participant
                        // sessionParticipantID "2" means the other participant
                        if let otherParticipant = bill.participants.first(where: { $0.id != userId }) {
                            let normalizedID = normalizeParticipantID(otherParticipant.id, displayName: otherParticipant.displayName, email: otherParticipant.email)
                            balances[normalizedID, default: 0.0] += amount
                            participantInfo[normalizedID] = (otherParticipant.displayName, otherParticipant.email)
                            print("🧮 \(otherParticipant.displayName) owes user +$\(amount) (running total: $\(balances[normalizedID] ?? 0.0))")
                        }
                    }
                }
            } else {
                print("🧮 User did not pay - checking if user owes")
                // User didn't pay - check if user owes money (negative balance)
                if let amountOwed = bill.calculatedTotals["1"], amountOwed > 0.01 {
                    let normalizedID = normalizeParticipantID(bill.paidBy, displayName: bill.paidByDisplayName, email: bill.paidByEmail)
                    balances[normalizedID, default: 0.0] -= amountOwed
                    participantInfo[normalizedID] = (bill.paidByDisplayName, bill.paidByEmail)
                    print("🧮 User owes \(bill.paidByDisplayName) -$\(amountOwed) (running total: $\(balances[normalizedID] ?? 0.0))")
                }
            }
        }
        
        print("🧮 Final net balances: \(balances)")
        
        let result = balances.compactMap { (participantID, netAmount) -> UIPersonDebt? in
            guard abs(netAmount) > 0.01,
                  let info = participantInfo[participantID] else { 
                print("❌ Skipping participant \(participantID): netAmount=\(netAmount)")
                return nil 
            }
            
            if netAmount > 0 {
                print("✅ Creating UIPersonDebt: \(info.name) owes user $\(netAmount)")
                return UIPersonDebt(
                    name: info.name,
                    total: netAmount,
                    color: .green // They owe you
                )
            } else {
                print("✅ Creating UIPersonDebt: User owes \(info.name) $\(abs(netAmount))")
                return UIPersonDebt(
                    name: info.name,
                    total: abs(netAmount),
                    color: .red // You owe them
                )
            }
        }.sorted { (debt1: UIPersonDebt, debt2: UIPersonDebt) -> Bool in
            debt1.total > debt2.total
        }
        
        print("🧮 Returning \(result.count) net balances")
        return result
    }
    
    /// Gets list of people who owe money to the current user (NET positive balances only)
    func getPeopleWhoOweUser() -> [UIPersonDebt] {
        return getNetBalances().filter { $0.color == .green }
    }
    
    /// Gets list of people the current user owes money to (NET negative balances only)
    func getPeopleUserOwes() -> [UIPersonDebt] {
        return getNetBalances().filter { $0.color == .red }
    }
}

// MARK: - User Balance Model

struct UserBalance {
    let totalOwed: Double // Amount user owes to others
    let totalOwedTo: Double // Amount others owe to user
    let activeBillIds: [String] // List of active bill IDs
    
    init(totalOwed: Double = 0.0, totalOwedTo: Double = 0.0, activeBillIds: [String] = []) {
        self.totalOwed = totalOwed
        self.totalOwedTo = totalOwedTo
        self.activeBillIds = activeBillIds
    }
    
    var netBalance: Double {
        return totalOwedTo - totalOwed
    }
    
    var hasDebts: Bool {
        return totalOwed > 0.01
    }
    
    var isOwed: Bool {
        return totalOwedTo > 0.01
    }
}

// MARK: - Bill Creation Errors

enum BillCreationError: LocalizedError {
    case sessionNotReady
    case invalidUser
    case invalidTotals
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotReady:
            return "Session is not ready for bill creation"
        case .invalidUser:
            return "Invalid user or payer information"
        case .invalidTotals:
            return "Bill totals don't match calculated amounts"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - FCM Token Management

class FCMTokenManager: ObservableObject {
    static let shared = FCMTokenManager()
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    private init() {}
    
    /// Updates the current user's FCM token in Firestore
    func updateFCMToken(_ token: String) async {
        guard let currentUser = auth.currentUser else {
            print("❌ updateFCMToken: No authenticated user")
            return
        }
        
        print("🔄 Updating FCM token for user: \(currentUser.uid)")
        
        do {
            try await db.collection("users").document(currentUser.uid).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "email": currentUser.email ?? "",
                "displayName": currentUser.displayName ?? "",
                "lastActiveAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ FCM token updated successfully in Firestore")
        } catch {
            print("❌ Failed to update FCM token: \(error)")
        }
    }
    
    /// Gets FCM tokens for participants by their email addresses
    func getFCMTokensForEmails(_ emails: [String]) async -> [String: String] {
        print("🔍 Looking up FCM tokens for emails: \(emails)")
        
        var tokenMap: [String: String] = [:]
        
        // Batch lookup users by email
        for email in emails {
            do {
                let querySnapshot = try await db.collection("users")
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments()
                
                if let document = querySnapshot.documents.first,
                   let fcmToken = document.data()["fcmToken"] as? String,
                   !fcmToken.isEmpty {
                    tokenMap[email] = fcmToken
                    print("✅ Found FCM token for \(email)")
                } else {
                    print("❌ No FCM token found for \(email)")
                }
            } catch {
                print("❌ Failed to lookup FCM token for \(email): \(error)")
            }
        }
        
        print("📊 FCM token lookup complete: \(tokenMap.count)/\(emails.count) tokens found")
        return tokenMap
    }
    
    /// Validates and refreshes FCM token if needed
    func validateAndRefreshToken() async {
        guard auth.currentUser != nil else {
            print("❌ validateAndRefreshToken: No authenticated user")
            return
        }
        
        // TODO: Uncomment after adding FirebaseMessaging
        /*
        do {
            let token = try await Messaging.messaging().token()
            print("🔄 Current FCM token: \(token)")
            await updateFCMToken(token)
        } catch {
            print("❌ Failed to get current FCM token: \(error)")
        }
        */
        print("⚠️ FCM token validation skipped - add FirebaseMessaging dependency")
    }
}

// MARK: - Push Notification Service

class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Sends push notifications to all participants about a new bill
    func sendBillNotificationToParticipants(bill: Bill) async {
        print("📨 Sending bill notifications for bill: \(bill.id)")
        
        // Get participant emails (excluding bill creator)
        let participantEmails = bill.participants
            .filter { $0.id != bill.createdBy }
            .map { $0.email }
        
        guard !participantEmails.isEmpty else {
            print("ℹ️ No participants to notify (excluding creator)")
            return
        }
        
        print("📧 Participant emails to notify: \(participantEmails)")
        
        // Get FCM tokens for participants
        let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
        
        guard !tokenMap.isEmpty else {
            print("❌ No FCM tokens found for any participants")
            return
        }
        
        // Create notification content
        let notificationData = createBillNotificationData(bill: bill)
        
        // Send notifications to each participant with retry logic
        for (email, fcmToken) in tokenMap {
            await sendNotificationWithRetry(
                fcmToken: fcmToken,
                data: notificationData,
                participantEmail: email,
                billId: bill.id
            )
        }
    }
    
    /// Creates notification data for a new bill
    private func createBillNotificationData(bill: Bill) -> [String: Any] {
        let title = "\(bill.paidByDisplayName) added '\(bill.displayName)' bill"
        let body = String(format: "Total: $%.2f • Tap to view details", bill.totalAmount)
        
        return [
            "title": title,
            "body": body,
            "billId": bill.id,
            "billAmount": bill.totalAmount,
            "billCreator": bill.paidByDisplayName,
            "type": "new_bill"
        ]
    }
    
    /// Sends notification with exponential backoff retry (3 attempts)
    private func sendNotificationWithRetry(fcmToken: String, data: [String: Any], participantEmail: String, billId: String) async {
        let maxRetries = 3
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                try await sendSingleNotification(fcmToken: fcmToken, data: data)
                print("✅ Notification sent successfully to \(participantEmail) on attempt \(attempt + 1)")
                return
            } catch {
                attempt += 1
                print("❌ Notification attempt \(attempt) failed for \(participantEmail): \(error)")
                
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt - 1))
                    print("⏳ Retrying in \(delay) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("💸 All retry attempts failed for \(participantEmail). Relying on History tab for notification.")
                }
            }
        }
    }
    
    /// Sends a single push notification using Firebase Cloud Functions
    private func sendSingleNotification(fcmToken: String, data: [String: Any]) async throws {
        // Create the notification payload
        let payload: [String: Any] = [
            "to": fcmToken,
            "notification": [
                "title": data["title"] as? String ?? "",
                "body": data["body"] as? String ?? "",
                "sound": "default"
            ],
            "data": data,
            "priority": "high",
            "content_available": true
        ]
        
        // Send via Firebase Cloud Functions or direct FCM API
        // For now, we'll store the notification request in Firestore and let a Cloud Function handle it
        // This is more reliable than direct FCM API calls from the client
        
        let notificationDoc: [String: Any] = [
            "fcmToken": fcmToken,
            "payload": payload,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
            "attempts": 0
        ]
        
        try await db.collection("notification_queue").addDocument(data: notificationDoc)
        print("📤 Notification queued for Cloud Function processing")
    }
}

// MARK: - Bill Calculation Helper

struct BillCalculator {
    
    /// Calculates who owes whom with proper rounding to ensure totals match
    static func calculateOwedAmounts(bill: Bill) -> [String: Double] {
        var owedAmounts: [String: Double] = [:]
        let paidByUserID = bill.paidBy
        
        // Initialize all participants with $0 owed
        for participant in bill.participants {
            if participant.id != paidByUserID {
                owedAmounts[participant.id] = 0.0
            }
        }
        
        // Calculate each item's split
        for item in bill.items {
            let participantCount = item.participantIDs.count
            guard participantCount > 0 else { continue }
            
            let baseAmount = item.price / Double(participantCount)
            let roundedBase = (baseAmount * 100).rounded() / 100 // Round to 2 decimal places
            
            // Calculate how much total we have after rounding
            let totalRounded = roundedBase * Double(participantCount)
            let remainder = item.price - totalRounded
            
            // Distribute the remainder (should be small cents)
            let remainderCents = Int((remainder * 100).rounded())
            
            for (index, participantID) in item.participantIDs.enumerated() {
                if participantID != paidByUserID {
                    var amountOwed = roundedBase
                    
                    // Add extra cent to first few participants to handle remainder
                    if index < remainderCents {
                        amountOwed += 0.01
                    }
                    
                    owedAmounts[participantID] = (owedAmounts[participantID] ?? 0.0) + amountOwed
                }
            }
        }
        
        // Final rounding to ensure 2 decimal places
        for participantID in owedAmounts.keys {
            owedAmounts[participantID] = ((owedAmounts[participantID] ?? 0.0) * 100).rounded() / 100
        }
        
        return owedAmounts
    }
    
    /// Validates that the calculated totals match the bill total
    static func validateBillTotals(bill: Bill) -> Bool {
        // Calculate total from individual item amounts
        let itemsTotal = bill.items.reduce(0.0) { $0 + $1.price }
        let expectedTotal = bill.totalAmount
        
        // The calculatedTotals only contains debts to the payer (not including payer's own share)
        // So we need to validate that items total matches the bill total instead
        let difference = abs(itemsTotal - expectedTotal)
        
        print("🔍 Bill validation:")
        print("   Expected total (bill.totalAmount): $\(expectedTotal)")
        print("   Items total (sum of item prices): $\(itemsTotal)")
        print("   Difference: $\(difference)")
        print("   Individual debts to payer: \(bill.calculatedTotals)")
        
        // Allow for small rounding differences (within 1 cent)
        let isValid = difference < 0.01
        print(isValid ? "✅ Bill totals valid" : "❌ Bill totals invalid")
        return isValid
    }
}

// MARK: - OCR Service
class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0.0
    @Published var lastResult: OCRResult?
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) async -> OCRResult {
        print("🚀 Starting OCR processing...")
        let startTime = Date()
        
        await MainActor.run {
            isProcessing = true
            progress = 0.1
            errorMessage = nil
        }
        
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage from UIImage")
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to process image"
            }
            return OCRResult(rawText: "", parsedItems: [], identifiedTotal: nil, suggestedAmounts: [], confidence: 0.0, processingTime: 0)
        }
        
        print("✅ CGImage created successfully, size: \(cgImage.width)x\(cgImage.height)")
        
        do {
            // Step 1: Extract text using Vision
            print("📖 Step 1: Extracting text using Vision framework...")
            await MainActor.run { progress = 0.3 }
            let extractedText = try await extractText(from: cgImage)
            
            print("📝 Step 1 Complete: Extracted \(extractedText.count) characters")
            if extractedText.isEmpty {
                print("⚠️ WARNING: No text extracted from image - OCR failed completely")
            } else {
                print("📝 OCR Text Preview: \(String(extractedText.prefix(100)))...")
            }
            
            // Step 2: Parse the extracted text
            print("🔍 Step 2: Parsing extracted text...")
            await MainActor.run { progress = 0.7 }
            let (parsedItems, identifiedTotal) = await parseReceiptText(extractedText)
            
            print("✅ Step 2 Complete: Found \(parsedItems.count) items, identified total: \(identifiedTotal ?? 0)")
            
            // Step 3: Calculate confidence and finish
            print("📊 Step 3: Calculating confidence...")
            await MainActor.run { progress = 0.9 }
            let confidence = calculateConfidence(text: extractedText, items: parsedItems)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let suggestedAmounts = extractPotentialAmounts(extractedText)
            
            let result = OCRResult(
                rawText: extractedText,
                parsedItems: parsedItems,
                identifiedTotal: identifiedTotal,
                suggestedAmounts: suggestedAmounts,
                confidence: confidence,
                processingTime: processingTime
            )
            
            print("🎯 OCR FINAL RESULT:")
            print("   Raw text length: \(extractedText.count)")
            print("   Items found: \(parsedItems.count)")
            for (index, item) in parsedItems.enumerated() {
                print("   Final Item \(index + 1): '\(item.name)' - $\(item.price)")
            }
            let totalValue = parsedItems.reduce(0) { $0.currencyAdd($1.price) }
            print("   Total value of all items: $\(totalValue)")
            print("   Confidence: \(confidence)")
            print("   Processing time: \(processingTime)s")
            
            await MainActor.run {
                self.lastResult = result
                self.progress = 1.0
                self.isProcessing = false
            }
            
            return result
            
        } catch {
            print("❌ OCR processing failed with error: \(error)")
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "OCR processing failed: \(error.localizedDescription)"
            }
            return OCRResult(rawText: "", parsedItems: [], identifiedTotal: nil, suggestedAmounts: [], confidence: 0.0, processingTime: Date().timeIntervalSince(startTime))
        }
    }
    
    private func extractText(from cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                print("🔍 OCR Processing Results:")
                print("📊 Number of text observations: \(observations.count)")
                
                // Filter low-confidence observations and improve text extraction
                let recognizedText = observations
                    .filter { $0.confidence > 0.2 } // Filter out very low confidence
                    .compactMap { observation in
                        // Get top candidate with better confidence handling
                        let topCandidate = observation.topCandidates(1).first?.string
                        if let text = topCandidate, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            print("📝 Detected text: '\(text)' (confidence: \(observation.confidence))")
                            return text
                        }
                        return nil
                    }
                    .joined(separator: "\n")
                
                print("🔍 OCR Raw Text Output:")
                print("======================")
                print(recognizedText.isEmpty ? "⚠️ NO TEXT DETECTED" : recognizedText)
                print("======================")
                print("📏 Total text length: \(recognizedText.count) characters")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Optimized Vision Framework settings for receipts
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true // Enable for better accuracy
            request.recognitionLanguages = ["en-US"] // Focus on English only
            request.minimumTextHeight = 0.005 // Lower threshold for small receipt text
            request.automaticallyDetectsLanguage = false // Disable for better performance
            
            // Optimize image processing options
            let options: [VNImageOption: Any] = [:]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: options)
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseReceiptText(_ text: String) async -> ([ReceiptItem], Double?) {
        print("🔍 OCR Raw Text Length: \(text.count) characters")
        print("📝 OCR Raw Text Preview: \(String(text.prefix(200)))")
        print("🔍 Using comprehensive item detection with amount matching...")
        
        // Step 1: Extract total, tax, tip first using regex
        let extractedTotal = extractReceiptTotal(text)
        let (taxAmount, tipAmount) = extractTaxAndTip(text)
        
        // Step 2: Clean text by removing total/tax/tip lines before sending to Apple Intelligence
        let cleanedText = removeFinancialSummaryLines(text: text)
        
        // Step 3: Use Apple Intelligence for item extraction (excluding financial summary)
        let detectedItems = await extractItemsWithAppleIntelligence(
            cleanedText: cleanedText,
            maxPrice: extractedTotal
        )
        
        // Step 4: Add tax and tip as separate items if detected
        let allItems = addFinancialSummaryItems(
            items: detectedItems,
            tax: taxAmount,
            tip: tipAmount
        )
        
        print("💰 Detected total: $\(extractedTotal ?? 0)")
        print("💰 Detected tax: $\(taxAmount ?? 0)")
        print("💰 Detected tip: $\(tipAmount ?? 0)")
        print("🍽️ Total items extracted with Apple Intelligence: \(allItems.count)")
        
        return (allItems, extractedTotal)
    }
    
    // MARK: - Smart Total Detection (No LLM Required)
    
    private func extractReceiptTotal(_ text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        var detectedTotals: [(amount: Double, confidence: Int, line: String)] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if cleanLine.isEmpty { continue }
            
            // Look for total patterns with different confidence levels
            if let total = findTotalInLine(cleanLine) {
                detectedTotals.append(total)
            }
        }
        
        // Sort by confidence (highest first), then by amount (highest first)
        detectedTotals.sort { first, second in
            if first.confidence != second.confidence {
                return first.confidence > second.confidence
            }
            return first.amount > second.amount
        }
        
        // Return the highest confidence total
        if let bestTotal = detectedTotals.first {
            print("✅ Best total match: $\(bestTotal.amount) from '\(bestTotal.line)' (confidence: \(bestTotal.confidence))")
            return bestTotal.amount
        }
        
        print("⚠️ No total found in receipt")
        return nil
    }
    
    private func extractTaxAndTip(_ text: String) -> (tax: Double?, tip: Double?) {
        let lines = text.components(separatedBy: .newlines)
        var taxAmount: Double? = nil
        var tipAmount: Double? = nil
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleanLine.lowercased()
            
            // Look for tax patterns
            if lowercased.contains("tax") && !lowercased.contains("total") {
                if let amount = extractAmountWithPattern(line: cleanLine, pattern: "tax[:\\s]*\\$?([0-9]+\\.[0-9]{2})") {
                    taxAmount = amount
                    print("💰 Found tax: $\(amount)")
                }
            }
            
            // Look for tip patterns
            if lowercased.contains("tip") && !lowercased.contains("total") {
                if let amount = extractAmountWithPattern(line: cleanLine, pattern: "tip[:\\s]*\\$?([0-9]+\\.[0-9]{2})") {
                    tipAmount = amount
                    print("💰 Found tip: $\(amount)")
                }
            }
        }
        
        return (taxAmount, tipAmount)
    }
    
    private func findTotalInLine(_ line: String) -> (amount: Double, confidence: Int, line: String)? {
        let lowercased = line.lowercased()
        
        // High confidence patterns (90+ confidence)
        let highConfidencePatterns = [
            (pattern: "total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 95),
            (pattern: "amount due[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 90),
            (pattern: "grand total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 95),
            (pattern: "final total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 90)
        ]
        
        // Check high confidence patterns first
        for patternInfo in highConfidencePatterns {
            if let amount = extractAmountWithPattern(line: lowercased, pattern: patternInfo.pattern) {
                return (amount: amount, confidence: patternInfo.confidence, line: line)
            }
        }
        
        // Medium confidence patterns (70-80 confidence)
        let mediumConfidencePatterns = [
            (pattern: "total[:\\s]*([0-9]+\\.[0-9]{2})", confidence: 80),
            (pattern: "\\$([0-9]+\\.[0-9]{2})\\s*total", confidence: 75),
            (pattern: "([0-9]+\\.[0-9]{2})\\s*total", confidence: 70)
        ]
        
        for patternInfo in mediumConfidencePatterns {
            if let amount = extractAmountWithPattern(line: lowercased, pattern: patternInfo.pattern) {
                return (amount: amount, confidence: patternInfo.confidence, line: line)
            }
        }
        
        // Low confidence: Large dollar amounts at end of line
        if let amount = extractAmountWithPattern(line: line, pattern: "\\$?([0-9]+\\.[0-9]{2})\\s*$") {
            if amount >= 10.0 && amount <= 500.0 { // Reasonable restaurant total range
                return (amount: amount, confidence: 50, line: line)
            }
        }
        
        return nil
    }
    
    private func extractAmountWithPattern(line: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        
        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: line) {
                    let amountString = String(line[swiftRange])
                    if let amount = Double(amountString), amount > 0 {
                        return amount
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Text Preprocessing for Apple Intelligence
    
    private func removeFinancialSummaryLines(text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        
        for line in lines {
            let lowercased = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip lines containing financial summary keywords
            let financialKeywords = [
                "total", "subtotal", "sub total", "grand total",
                "tax", "sales tax", "tip", "gratuity", "service charge",
                "amount due", "balance", "change", "payment"
            ]
            
            var shouldSkip = false
            for keyword in financialKeywords {
                if lowercased.contains(keyword) {
                    shouldSkip = true
                    print("🚫 Filtering out financial line: '\(line.trimmingCharacters(in: .whitespacesAndNewlines))'")
                    break
                }
            }
            
            if !shouldSkip {
                cleanedLines.append(line)
            }
        }
        
        let cleanedText = cleanedLines.joined(separator: "\n")
        print("📝 Cleaned text for Apple Intelligence (\(cleanedLines.count) lines):")
        print(cleanedText)
        
        return cleanedText
    }
    
    private func addFinancialSummaryItems(
        items: [ReceiptItem],
        tax: Double?,
        tip: Double?
    ) -> [ReceiptItem] {
        
        var allItems = items
        
        // Add tax as a separate item if detected
        if let taxAmount = tax, taxAmount > 0 {
            allItems.append(ReceiptItem(name: "Tax", price: taxAmount))
            print("💰 Added tax item: $\(taxAmount)")
        }
        
        // Add tip as a separate item if detected
        if let tipAmount = tip, tipAmount > 0 {
            allItems.append(ReceiptItem(name: "Tip", price: tipAmount))
            print("💰 Added tip item: $\(tipAmount)")
        }
        
        return allItems
    }
    
    // MARK: - Apple Intelligence Item Detection
    
    private func extractItemsWithAppleIntelligence(
        cleanedText: String,
        maxPrice: Double?
    ) async -> [ReceiptItem] {
        
        print("🧠 Using Apple Intelligence for item parsing...")
        print("💰 Max price filter: $\(maxPrice ?? 999)")
        
        // First, use Apple Intelligence to detect tax/tip values for filtering
        let (detectedTaxTotal, detectedTipTotal) = await detectTaxTipWithAppleIntelligence(text: cleanedText)
        
        print("🧾 Apple Intelligence detected:")
        if detectedTaxTotal > 0 {
            print("   Tax: $\(detectedTaxTotal)")
        }
        if detectedTipTotal > 0 {
            print("   Tip: $\(detectedTipTotal)")
        }
        
        // Use Natural Language framework for intelligent text analysis
        let items = await parseReceiptWithNaturalLanguage(
            text: cleanedText, 
            maxPrice: maxPrice,
            excludeTaxAmount: detectedTaxTotal > 0 ? detectedTaxTotal : nil,
            excludeTipAmount: detectedTipTotal > 0 ? detectedTipTotal : nil
        )
        
        return items
    }
    
    private func parseReceiptWithNaturalLanguage(
        text: String, 
        maxPrice: Double?,
        excludeTaxAmount: Double? = nil,
        excludeTipAmount: Double? = nil
    ) async -> [ReceiptItem] {
        print("🔍 Analyzing receipt text with Natural Language framework...")
        
        var extractedItems: [ReceiptItem] = []
        var placeholderIndex = 1
        
        // Split text into logical lines for analysis
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Use NL framework to understand each line
        for line in lines {
            if let item = await analyzeLineForItem(
                line: line, 
                maxPrice: maxPrice,
                excludeTaxAmount: excludeTaxAmount,
                excludeTipAmount: excludeTipAmount,
                placeholderIndex: &placeholderIndex
            ) {
                extractedItems.append(item)
                print("🍽️ Extracted: '\(item.name)' - $\(item.price)")
            }
        }
        
        print("✅ Natural Language analysis complete: \(extractedItems.count) items found")
        return extractedItems
    }
    
    private func analyzeLineForItem(
        line: String, 
        maxPrice: Double?,
        excludeTaxAmount: Double? = nil,
        excludeTipAmount: Double? = nil,
        placeholderIndex: inout Int
    ) async -> ReceiptItem? {
        
        // Skip obvious non-item lines
        if shouldSkipLineForIntelligentAnalysis(line) {
            return nil
        }
        
        // Extract price pattern first
        guard let price = extractPriceFromLine(line) else {
            return nil
        }
        
        // Apply price filtering - exclude items >= total (duplicate totals on receipt)
        if let maxPrice = maxPrice, price >= maxPrice {
            print("🚫 Excluding item with price $\(price) >= total $\(maxPrice)")
            return nil
        }
        
        // Exclude items that match detected tax amounts
        if let taxAmount = excludeTaxAmount, abs(price - taxAmount) < 0.01 {
            print("🚫 Excluding item with price $\(price) matching tax amount $\(taxAmount)")
            return nil
        }
        
        // Exclude items that match detected tip amounts  
        if let tipAmount = excludeTipAmount, abs(price - tipAmount) < 0.01 {
            print("🚫 Excluding item with price $\(price) matching tip amount $\(tipAmount)")
            return nil
        }
        
        // Use Apple Intelligence (Natural Language) to extract item name
        print("🤖 Processing line: '\(line)' with price $\(price)")
        let itemName = await extractItemNameWithAppleIntelligence(line: line, price: price)
        
        let finalItemName: String
        if let name = itemName, !name.isEmpty && name.count >= 3 {
            // Apple Intelligence found a meaningful item name
            finalItemName = name
            print("🧠 Apple Intelligence detected name: '\(name)' from line: '\(line)'")
        } else {
            // No clear name detected, use placeholder
            finalItemName = "Item \(placeholderIndex)"
            placeholderIndex += 1
            print("🔤 Using placeholder name: '\(finalItemName)' for line: '\(line)'")
        }
        
        return ReceiptItem(name: finalItemName, price: price)
    }
    
    private func shouldSkipLineForIntelligentAnalysis(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip header/footer patterns
        let skipPatterns = [
            "receipt", "thank you", "visit", "address", "phone", "store",
            "location", "cashier", "register", "server", "table",
            "date", "time", "order #", "transaction", "card ending",
            "auth", "ref", "batch"
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip very short lines
        if line.count < 3 {
            return true
        }
        
        // Skip lines that are only numbers/symbols
        if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) {
            return true
        }
        
        return false
    }
    
    private func extractItemNameWithAppleIntelligence(line: String, price: Double) async -> String? {
        // Remove the price from the line to isolate potential item name
        let priceStrings = [
            "$\(String(format: "%.2f", price))", 
            String(format: "%.2f", price),
            "$\(Int(price))",
            String(Int(price))
        ]
        
        var cleanLine = line
        for priceString in priceStrings {
            cleanLine = cleanLine.replacingOccurrences(of: priceString, with: " ")
        }
        
        // Clean up the remaining text
        cleanLine = cleanLine.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanLine = cleanLine.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        cleanLine = cleanLine.trimmingCharacters(in: CharacterSet(charactersIn: ".-_*()[]{}"))
        
        // Skip if too short or only numbers
        guard cleanLine.count >= 3 else { return nil }
        guard cleanLine.contains(where: { $0.isLetter }) else { return nil }
        
        // Use Natural Language framework to analyze the text semantically
        let analysis = await analyzeTextWithNaturalLanguage(cleanLine)
        
        if analysis {
            let cleanedName = cleanLine.capitalized
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedName
        }
        
        return nil
    }
    
    private func analyzeTextWithNaturalLanguage(_ text: String) async -> Bool {
        print("🔬 Analyzing text: '\(text)'")
        
        // Use NLTagger for semantic analysis
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var hasNouns = false
        var hasProperNouns = false
        var wordCount = 0
        
        // Analyze lexical classes (nouns, adjectives, etc.)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            wordCount += 1
            
            if tag == .noun {
                hasNouns = true
            } else if tag == .adjective {
                hasNouns = true  // Adjectives often describe products
            }
            
            return true
        }
        
        // Analyze for proper nouns (brand names, etc.)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .organizationName || tag == .placeName {
                hasProperNouns = true
            }
            return true
        }
        
        // Check for common food/product keywords
        let productKeywords = [
            "sandwich", "salad", "burger", "pizza", "pasta", "chicken", "beef", "fish",
            "soup", "appetizer", "dessert", "cake", "pie", "drink", "coffee", "tea",
            "special", "combo", "meal", "plate", "bowl", "cup", "bottle", "glass"
        ]
        
        let lowercased = text.lowercased()
        let hasProductKeywords = productKeywords.contains { lowercased.contains($0) }
        
        // Decision logic: Is this likely a product name?
        let isLikelyProduct = (hasNouns || hasProperNouns || hasProductKeywords) && 
                             wordCount >= 1 && 
                             wordCount <= 6 &&
                             !isObviousNonProduct(text)
        
        print("📊 Analysis result for '\(text)':")
        print("   - Has nouns: \(hasNouns)")
        print("   - Has proper nouns: \(hasProperNouns)")
        print("   - Has product keywords: \(hasProductKeywords)")
        print("   - Word count: \(wordCount)")
        print("   - Is obvious non-product: \(isObviousNonProduct(text))")
        print("   - Final decision: \(isLikelyProduct ? "✅ PRODUCT" : "❌ NOT PRODUCT")")
        
        return isLikelyProduct
    }
    
    private func isObviousNonProduct(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Skip obvious non-product text
        let nonProductPatterns = [
            "qty", "quantity", "each", "ea", "lb", "oz", "gal", "ct", "pk",
            "server", "table", "order", "receipt", "thank", "visit"
        ]
        
        for pattern in nonProductPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func isLikelyProductName(_ text: String) -> Bool {
        // Must have reasonable length
        guard text.count >= 2 && text.count <= 50 else { return false }
        
        // Must contain letters
        guard text.contains(where: { $0.isLetter }) else { return false }
        
        // Use Natural Language to check if it's meaningful text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var hasNouns = false
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, _ in
            if tag == .noun || tag == .adjective {
                hasNouns = true
                return false // Stop enumeration
            }
            return true
        }
        
        return hasNouns || text.split(separator: " ").count >= 2
    }
    
    // MARK: - Apple Intelligence Tax/Tip Detection
    
    private func detectTaxTipWithAppleIntelligence(text: String) async -> (taxTotal: Double, tipTotal: Double) {
        print("🧾 Detecting tax/tip with hybrid approach...")
        
        // Step 1: Use regex for primary detection (fast, reliable)
        let regexTaxAmounts = extractTaxAmountsWithRegex(text)
        let regexTipAmounts = extractTipAmountsWithRegex(text)
        
        print("🔍 Regex detected:")
        print("   Tax amounts: \(regexTaxAmounts)")
        print("   Tip amounts: \(regexTipAmounts)")
        
        // Step 2: Use Apple Intelligence for validation and edge cases
        let aiResults = await validateTaxTipWithAppleIntelligence(
            text: text,
            regexTaxAmounts: regexTaxAmounts,
            regexTipAmounts: regexTipAmounts
        )
        
        // Step 3: Sum the validated results
        let totalTax = aiResults.validatedTaxAmounts.reduce(0, +)
        let totalTip = aiResults.validatedTipAmounts.reduce(0, +)
        
        print("💡 Final results after Apple Intelligence validation:")
        print("   Total Tax: $\(totalTax)")
        print("   Total Tip: $\(totalTip)")
        
        return (taxTotal: totalTax, tipTotal: totalTip)
    }
    
    private func extractTaxAmountsWithRegex(_ text: String) -> [Double] {
        let taxPatterns = [
            #"(?i)(?:sales?\s*)?tax[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:state|local|city)\s*tax[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)tax\s*(?:amount|total)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:^|\s)tx[\s:]*\$?(\d+\.?\d*)"#
        ]
        
        return extractAmountsUsingPatterns(text: text, patterns: taxPatterns)
    }
    
    private func extractTipAmountsWithRegex(_ text: String) -> [Double] {
        let tipPatterns = [
            #"(?i)tip[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)gratuity[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)service\s*(?:charge|fee)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:auto|automatic)\s*(?:tip|gratuity)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:^|\s)grat[\s:]*\$?(\d+\.?\d*)"#
        ]
        
        return extractAmountsUsingPatterns(text: text, patterns: tipPatterns)
    }
    
    private func extractAmountsUsingPatterns(text: String, patterns: [String]) -> [Double] {
        var amounts: [Double] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[range])
                    if let amount = Double(amountString), amount > 0 {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        return amounts
    }
    
    private func validateTaxTipWithAppleIntelligence(
        text: String,
        regexTaxAmounts: [Double],
        regexTipAmounts: [Double]
    ) async -> (validatedTaxAmounts: [Double], validatedTipAmounts: [Double]) {
        
        print("🤖 Apple Intelligence validating detected amounts...")
        
        // If regex found clear results, validate them with AI
        var validatedTax = regexTaxAmounts
        var validatedTip = regexTipAmounts
        
        // Use Natural Language to look for additional edge cases
        let additionalTaxTip = await findAdditionalTaxTipWithNL(text: text)
        
        // Add any additional amounts found by AI that weren't caught by regex
        for amount in additionalTaxTip.additionalTax {
            if !regexTaxAmounts.contains(where: { abs($0 - amount) < 0.01 }) {
                print("🧠 Apple Intelligence found additional tax: $\(amount)")
                validatedTax.append(amount)
            }
        }
        
        for amount in additionalTaxTip.additionalTip {
            if !regexTipAmounts.contains(where: { abs($0 - amount) < 0.01 }) {
                print("🧠 Apple Intelligence found additional tip: $\(amount)")
                validatedTip.append(amount)
            }
        }
        
        return (validatedTaxAmounts: validatedTax, validatedTipAmounts: validatedTip)
    }
    
    private func findAdditionalTaxTipWithNL(text: String) async -> (additionalTax: [Double], additionalTip: [Double]) {
        // Use NLTagger to find lines that semantically relate to tax/tip concepts
        let lines = text.components(separatedBy: .newlines)
        var additionalTax: [Double] = []
        var additionalTip: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanLine.isEmpty else { continue }
            
            // Extract any price from the line first
            guard let price = extractPriceFromLine(cleanLine) else { continue }
            
            // Use semantic analysis to determine if this line relates to tax or tip
            let isTaxRelated = await isLineTaxRelated(cleanLine)
            let isTipRelated = await isLineTipRelated(cleanLine)
            
            if isTaxRelated {
                additionalTax.append(price)
                print("🔬 NL detected tax-related line: '\(cleanLine)' -> $\(price)")
            } else if isTipRelated {
                additionalTip.append(price)
                print("🔬 NL detected tip-related line: '\(cleanLine)' -> $\(price)")
            }
        }
        
        return (additionalTax: additionalTax, additionalTip: additionalTip)
    }
    
    private func isLineTaxRelated(_ text: String) async -> Bool {
        // Use semantic concepts to identify tax-related content
        let taxConcepts = ["tax", "taxation", "levy", "charge", "government", "state", "sales"]
        let lowercased = text.lowercased()
        
        // Check for semantic similarity using NL
        return taxConcepts.contains { concept in
            lowercased.contains(concept) || 
            semanticallyRelated(text: lowercased, concept: concept)
        }
    }
    
    private func isLineTipRelated(_ text: String) async -> Bool {
        // Use semantic concepts to identify tip-related content  
        let tipConcepts = ["tip", "gratuity", "service", "server", "waiter", "staff"]
        let lowercased = text.lowercased()
        
        // Check for semantic similarity using NL
        return tipConcepts.contains { concept in
            lowercased.contains(concept) ||
            semanticallyRelated(text: lowercased, concept: concept)
        }
    }
    
    private func semanticallyRelated(text: String, concept: String) -> Bool {
        // Simple semantic similarity check using word embeddings concept
        // This is a simplified version - in a full implementation you might use
        // more sophisticated NL techniques
        
        let conceptSynonyms: [String: [String]] = [
            "tax": ["fee", "charge", "levy", "duty"],
            "tip": ["gratuity", "bonus", "reward", "service"],
            "service": ["assistance", "help", "support"]
        ]
        
        if let synonyms = conceptSynonyms[concept] {
            return synonyms.contains { text.contains($0) }
        }
        
        return false
    }
    
    private func validateAndCompleteItems(
        items: [ReceiptItem],
        total: Double?,
        tax: Double?,
        tip: Double?
    ) -> [ReceiptItem] {
        
        var completeItems = items
        
        // Add tax and tip as separate items if detected
        if let taxAmount = tax, taxAmount > 0 {
            completeItems.append(ReceiptItem(name: "Tax", price: taxAmount))
            print("💰 Added tax item: $\(taxAmount)")
        }
        
        if let tipAmount = tip, tipAmount > 0 {
            completeItems.append(ReceiptItem(name: "Tip", price: tipAmount))
            print("💰 Added tip item: $\(tipAmount)")
        }
        
        // Validate against total if available
        if let totalAmount = total {
            let itemsTotal = completeItems.reduce(0) { $0.currencyAdd($1.price) }
            let difference = abs(totalAmount - itemsTotal)
            
            print("📊 Validation check:")
            print("   Items total: $\(itemsTotal)")
            print("   Receipt total: $\(totalAmount)")
            print("   Difference: $\(difference)")
            
            if difference > 1.0 {
                print("⚠️ Large difference detected - items may be incomplete")
            } else {
                print("✅ Items total matches receipt within tolerance")
            }
        }
        
        return completeItems
    }
    
    // MARK: - Legacy Item Detection (Keep for fallback)
    
    private func extractItemsWithNames(_ text: String, maxPrice: Double?) -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var detectedItems: [ReceiptItem] = []
        
        print("🔍 Processing \(lines.count) lines for item detection...")
        print("💰 Using max price filter: $\(maxPrice ?? 999)")
        
        // Method 1: Same-line parsing (existing patterns)
        detectedItems.append(contentsOf: parseSameLineItems(lines, maxPrice: maxPrice))
        
        // Method 2: Multi-line parsing (name on one line, price on next)
        detectedItems.append(contentsOf: parseMultiLineItems(lines, maxPrice: maxPrice))
        
        // Method 3: Block parsing (all names, then all prices)
        detectedItems.append(contentsOf: parseBlockItems(lines, maxPrice: maxPrice))
        
        print("✅ Total detected items: \(detectedItems.count)")
        for item in detectedItems {
            print("🍽️ Item: '\(item.name)' - $\(item.price)")
        }
        
        return detectedItems
    }
    
    private func shouldSkipLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip header/footer information
        let skipPatterns = [
            "receipt", "thank you", "address", "phone", "store", "location",
            "cashier", "register", "transaction", "date", "time",
            "tax", "tip", "total", "subtotal", "amount due", "balance"  // Skip tax/tip/total from items
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip lines that are just numbers or special characters
        if line.count < 2 || line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) {
            return true
        }
        
        return false
    }
    
    // Method 1: Same-line parsing
    private func parseSameLineItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanLine.isEmpty || shouldSkipLine(cleanLine) {
                continue
            }
            
            if let item = parseItemFromLine(cleanLine) {
                if isValidItemPrice(item.price, maxPrice: maxPrice) {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    // Method 2: Multi-line parsing (item name, then price on next line)
    private func parseMultiLineItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        
        for i in 0..<(lines.count - 1) {
            let currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let nextLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if current line looks like an item name and next line looks like a price
            if isLikelyItemName(currentLine) && isLikelyPrice(nextLine) {
                if let price = extractPriceFromLine(nextLine) {
                    if isValidItemPrice(price, maxPrice: maxPrice) {
                        let itemName = cleanItemName(currentLine)
                        if !itemName.isEmpty {
                            let item = ReceiptItem(name: itemName, price: price)
                            items.append(item)
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    // Method 3: Block parsing (all items listed, then all prices)
    private func parseBlockItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        var itemNames: [String] = []
        var prices: [Double] = []
        
        // First pass: collect potential item names and prices separately
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanLine.isEmpty || shouldSkipLine(cleanLine) {
                continue
            }
            
            // If line is just a price, add to prices array
            if let price = extractPriceFromLine(cleanLine), isPurePrice(cleanLine) {
                if isValidItemPrice(price, maxPrice: maxPrice) {
                    prices.append(price)
                }
            }
            // If line looks like an item name (has letters, not just price), add to names
            else if isLikelyItemName(cleanLine) && !isPurePrice(cleanLine) {
                itemNames.append(cleanItemName(cleanLine))
            }
        }
        
        // Match names with prices (if counts are similar)
        let minCount = min(itemNames.count, prices.count)
        if minCount > 0 && abs(itemNames.count - prices.count) <= 2 {
            for i in 0..<minCount {
                let item = ReceiptItem(name: itemNames[i], price: prices[i])
                items.append(item)
            }
        }
        
        return items
    }
    
    private func isLikelyItemName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 3 characters and contain letters
        guard trimmed.count >= 3 && trimmed.contains(where: { $0.isLetter }) else {
            return false
        }
        
        // Should not be just a price
        return !isPurePrice(trimmed)
    }
    
    private func isLikelyPrice(_ line: String) -> Bool {
        return extractPriceFromLine(line) != nil
    }
    
    private func isPurePrice(_ line: String) -> Bool {
        // Check if line is just a price (with optional $ and spaces)
        let cleanLine = line.replacingOccurrences(of: " ", with: "")
        let pricePattern = "^\\$?[0-9]+\\.[0-9]{2}$"
        
        guard let regex = try? NSRegularExpression(pattern: pricePattern, options: []) else {
            return false
        }
        
        let range = NSRange(location: 0, length: cleanLine.count)
        return regex.firstMatch(in: cleanLine, options: [], range: range) != nil
    }
    
    private func extractPriceFromLine(_ line: String) -> Double? {
        let pricePattern = "\\$?([0-9]+\\.[0-9]{2})"
        
        guard let regex = try? NSRegularExpression(pattern: pricePattern, options: []) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let priceString = String(line[range])
                if let price = Double(priceString) {
                    return price
                }
            }
        }
        
        return nil
    }
    
    private func parseItemFromLine(_ line: String) -> ReceiptItem? {
        // Pattern 1: Item name followed by price at end of line
        // Example: "Chicken Sandwich    12.99" or "MILK 1GAL $3.49"
        let pattern1 = "^(.+?)\\s+\\$?([0-9]+\\.[0-9]{2})\\s*$"
        
        if let match = extractWithPattern(line: line, pattern: pattern1) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            // Validate the extracted data
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        // Pattern 2: Price at beginning followed by item name
        // Example: "$12.99 Chicken Sandwich" or "3.49 MILK 1GAL"
        let pattern2 = "^\\$?([0-9]+\\.[0-9]{2})\\s+(.+)$"
        
        if let match = extractWithPattern(line: line, pattern: pattern2, swapNamePrice: true) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        // Pattern 3: Item name and price separated by multiple spaces or tabs
        // Example: "Chicken Sandwich        12.99"
        let pattern3 = "^(.+?)\\s{2,}\\$?([0-9]+\\.[0-9]{2})\\s*$"
        
        if let match = extractWithPattern(line: line, pattern: pattern3) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        return nil
    }
    
    private func extractWithPattern(line: String, pattern: String, swapNamePrice: Bool = false) -> (name: String, price: Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        
        guard let match = matches.first, match.numberOfRanges >= 3 else {
            return nil
        }
        
        let range1 = match.range(at: 1)
        let range2 = match.range(at: 2)
        
        guard let swiftRange1 = Range(range1, in: line),
              let swiftRange2 = Range(range2, in: line) else {
            return nil
        }
        
        let string1 = String(line[swiftRange1])
        let string2 = String(line[swiftRange2])
        
        if swapNamePrice {
            // Pattern 2: price comes first, then name
            guard let price = Double(string1) else { return nil }
            return (name: string2, price: price)
        } else {
            // Pattern 1 & 3: name comes first, then price
            guard let price = Double(string2) else { return nil }
            return (name: string1, price: price)
        }
    }
    
    private func isValidItemName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 2 characters
        guard trimmed.count >= 2 else { return false }
        
        // Must contain at least one letter
        guard trimmed.contains(where: { $0.isLetter }) else { return false }
        
        // Skip obvious non-items
        let lowercased = trimmed.lowercased()
        let invalidNames = ["qty", "ea", "each", "lb", "oz", "gal", "ct", "pk"]
        
        for invalid in invalidNames {
            if lowercased == invalid {
                return false
            }
        }
        
        return true
    }
    
    private func isValidItemPrice(_ price: Double, maxPrice: Double?) -> Bool {
        // Must be positive
        guard price > 0 else { return false }
        
        // If we have a total, price should be less than total (items can't cost more than total bill)
        if let maxPrice = maxPrice {
            return price < maxPrice
        }
        
        // Without total reference, accept reasonable range
        return price <= 500.0
    }
    
    private func cleanItemName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common suffixes that aren't part of the item name
        let suffixesToRemove = ["EA", "LB", "OZ", "GAL", "CT", "PK", "@"]
        
        for suffix in suffixesToRemove {
            if cleaned.hasSuffix(" " + suffix) {
                cleaned = String(cleaned.dropLast(suffix.count + 1))
            }
        }
        
        // Capitalize first letter of each word for better presentation
        return cleaned.capitalized
    }
    
    // Don't remove duplicates - allow multiple identical items (ordered by different people)
    private func removeDuplicateItems(_ items: [ReceiptItem]) -> [ReceiptItem] {
        return items
    }
    
    // MARK: - Comprehensive Item Detection
    
    private func completeItemsToMatchTotal(
        text: String, 
        itemsWithNames: [ReceiptItem], 
        total: Double?, 
        tax: Double?, 
        tip: Double?
    ) -> [ReceiptItem] {
        
        var allItems = itemsWithNames
        
        guard let totalAmount = total else {
            print("⚠️ No total found, returning items with names only")
            return allItems
        }
        
        // Calculate what we've already accounted for
        let namedItemsTotal = itemsWithNames.reduce(0) { $0.currencyAdd($1.price) }
        let taxAmount = tax ?? 0
        let tipAmount = tip ?? 0
        let accountedAmount = namedItemsTotal.currencyAdd(taxAmount).currencyAdd(tipAmount)
        
        print("📊 Accounting check:")
        print("   Named items total: $\(namedItemsTotal)")
        print("   Tax: $\(taxAmount)")
        print("   Tip: $\(tipAmount)")
        print("   Accounted for: $\(accountedAmount)")
        print("   Receipt total: $\(totalAmount)")
        print("   Missing: $\(totalAmount - accountedAmount)")
        
        // If we're already close to the total, don't add more items
        if abs(totalAmount - accountedAmount) <= 0.50 {
            print("✅ Amounts match within $0.50 tolerance")
            return addTaxAndTipItems(items: allItems, tax: tax, tip: tip)
        }
        
        // Find all dollar amounts in the text that we haven't used yet
        let usedAmounts = Set(itemsWithNames.map { $0.price })
        let allAmounts = extractAllAmountsFromText(text, excluding: usedAmounts, maxPrice: totalAmount)
        
        // Try to find combination of amounts that gets us close to the total
        let missingAmount = totalAmount - accountedAmount
        let additionalItems = findBestAmountCombination(
            amounts: allAmounts, 
            targetAmount: missingAmount,
            startingIndex: itemsWithNames.count + 1
        )
        
        print("🔍 Found \(additionalItems.count) additional items to match total")
        
        allItems.append(contentsOf: additionalItems)
        
        // Add tax and tip as separate items
        return addTaxAndTipItems(items: allItems, tax: tax, tip: tip)
    }
    
    private func extractAllAmountsFromText(_ text: String, excluding usedAmounts: Set<Double>, maxPrice: Double) -> [Double] {
        let lines = text.components(separatedBy: .newlines)
        var amounts: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip lines that are obviously not items
            if shouldSkipLineForAmountExtraction(cleanLine) {
                continue
            }
            
            // Extract all amounts from this line
            if let lineAmounts = extractAmountsFromLine(cleanLine) {
                for amount in lineAmounts {
                    // Only include if we haven't already used this amount and it's reasonable
                    if !usedAmounts.contains(amount) && amount > 0 && amount < maxPrice {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        let uniqueAmounts = Array(Set(amounts)).sorted()
        print("💰 Available amounts for matching: \(uniqueAmounts)")
        
        return uniqueAmounts
    }
    
    private func shouldSkipLineForAmountExtraction(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip obvious non-item lines
        let skipPatterns = [
            "receipt", "thank you", "address", "phone", "store", "location",
            "cashier", "register", "transaction", "date", "time", "card #",
            "total", "subtotal", "tax", "tip", "change", "cash", "credit"
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func extractAmountsFromLine(_ line: String) -> [Double]? {
        let amountPattern = "\\$?([0-9]+\\.[0-9]{2})"
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: []) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        var amounts: [Double] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let amountString = String(line[range])
                if let amount = Double(amountString) {
                    amounts.append(amount)
                }
            }
        }
        
        return amounts.isEmpty ? nil : amounts
    }
    
    private func findBestAmountCombination(amounts: [Double], targetAmount: Double, startingIndex: Int) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        var remainingTarget = targetAmount
        var itemIndex = startingIndex
        
        // Sort amounts in descending order to try larger amounts first
        let sortedAmounts = amounts.sorted(by: >)
        
        for amount in sortedAmounts {
            // If this amount gets us closer to the target, use it
            if amount <= remainingTarget + 1.0 { // Allow some tolerance
                let item = ReceiptItem(name: "Item \(itemIndex)", price: amount)
                items.append(item)
                remainingTarget -= amount
                itemIndex += 1
                
                print("💡 Added placeholder item: Item \(itemIndex - 1) - $\(amount)")
                
                // If we're close enough to the target, stop
                if abs(remainingTarget) <= 1.0 {
                    break
                }
            }
        }
        
        return items
    }
    
    private func addTaxAndTipItems(items: [ReceiptItem], tax: Double?, tip: Double?) -> [ReceiptItem] {
        var allItems = items
        
        // Add tax as a separate item if detected
        if let taxAmount = tax, taxAmount > 0 {
            let taxItem = ReceiptItem(name: "Tax", price: taxAmount)
            allItems.append(taxItem)
            print("💰 Added tax item: $\(taxAmount)")
        }
        
        // Add tip as a separate item if detected
        if let tipAmount = tip, tipAmount > 0 {
            let tipItem = ReceiptItem(name: "Tip", price: tipAmount)
            allItems.append(tipItem)
            print("💰 Added tip item: $\(tipAmount)")
        }
        
        return allItems
    }
    
    private func extractPotentialAmounts(_ text: String) -> [Double] {
        let lines = text.components(separatedBy: .newlines)
        var amounts: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip header/footer lines
            let lowercased = cleanLine.lowercased()
            if lowercased.contains("receipt") || 
               lowercased.contains("thank you") ||
               lowercased.contains("address") ||
               lowercased.contains("phone") {
                continue
            }
            
            // Find all dollar amounts in the line
            let amountPattern = "\\$?([0-9]+\\.[0-9]{2})"
            if let regex = try? NSRegularExpression(pattern: amountPattern, options: []) {
                let matches = regex.matches(in: cleanLine, options: [], range: NSRange(location: 0, length: cleanLine.count))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: cleanLine) {
                        let amountString = String(cleanLine[range])
                        if let amount = Double(amountString) {
                            // Filter reasonable item prices (not tax rates, tips, etc.)
                            if amount >= 1.0 && amount <= 100.0 {
                                amounts.append(amount)
                            }
                        }
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        let uniqueAmounts = Array(Set(amounts)).sorted()
        
        for amount in uniqueAmounts {
            print("💰 Potential item amount: $\(amount)")
        }
        
        return uniqueAmounts
    }
    
    private func calculateConfidence(text: String, items: [ReceiptItem]) -> Float {
        if text.isEmpty {
            return 0.0
        }
        
        let textLength = Float(text.count)
        let itemCount = Float(items.count)
        
        var confidence: Float = min(textLength / 100.0, 1.0)
        confidence = confidence * 0.7 + (itemCount > 0 ? 0.3 : 0.0)
        
        return min(max(confidence, 0.0), 1.0)
    }
    
    // Debug method to test parsing with known text
    func testParsing() async -> OCRResult {
        print("🧪 Testing enhanced Apple Intelligence with proper filtering...")
        
        // Test with realistic receipt that has all edge cases
        let sampleText = """
        RESTAURANT ABC
        123 Main Street
        Order #12345
        
        Chicken Sandwich 12.99
        Caesar Salad 8.50
        Appetizer Special 6.75
        4.25
        Coke 2.99
        3.45
        48.05
        
        Subtotal 38.93
        Sales Tax 3.12
        Tip 6.00
        
        Total 48.05
        Grand Total 48.05
        Thank you for visiting!
        """
        
        let (items, total) = await parseReceiptText(sampleText)
        let suggestedAmounts = extractPotentialAmounts(sampleText)
        
        return OCRResult(
            rawText: sampleText,
            parsedItems: items,
            identifiedTotal: total,
            suggestedAmounts: suggestedAmounts,
            confidence: 0.9,
            processingTime: 0.1
        )
    }
    
    // MARK: - Confirmation Analysis Methods
    
    func analyzeReceiptForConfirmation(text: String) async -> ReceiptAnalysis {
        print("🔍 Analyzing receipt for confirmation screen...")
        
        // Step 1: Use existing regex patterns to detect tax, tip, and total
        let (detectedTaxOptional, detectedTipOptional) = extractTaxAndTip(text)
        let detectedTotal = extractReceiptTotal(text)
        
        let detectedTax = detectedTaxOptional ?? 0.0
        let detectedTip = detectedTipOptional ?? 0.0
        
        // Step 2: Predict item count using the logic discussed
        let predictedItemCount = await predictItemCount(text: text)
        
        print("📊 Confirmation analysis results:")
        print("   Tax: $\(detectedTax)")
        print("   Tip: $\(detectedTip)")  
        print("   Total: $\(detectedTotal ?? 0)")
        print("   Predicted items: \(predictedItemCount)")
        
        return ReceiptAnalysis(
            tax: detectedTax,
            tip: detectedTip,
            total: detectedTotal ?? 0,
            itemCount: predictedItemCount
        )
    }
    
    // MARK: - LLM-based Individual Item Price Extraction
    
    private func extractIndividualItemPricesWithFiltering(
        text: String,
        targetTotal: Double,
        expectedCount: Int,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        print("🔍 Extracting individual item prices with tax/tip filtering...")
        return await extractItemsWithAppleIntelligence(
            text: text,
            targetPrice: targetTotal,
            expectedCount: expectedCount
        )
    }
    
    private func extractIndividualItemPrices(
        text: String,
        targetTotal: Double,
        expectedCount: Int
    ) async -> [(name: String, price: Double)] {
        print("🤖 Using Apple Intelligence to extract individual item prices...")
        print("   Target total: $\(targetTotal)")
        print("   Expected items: \(expectedCount)")
        
        // Use Natural Language processing to find individual item prices in order
        let lines = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        var extractedItems: [(name: String, price: Double)] = []
        
        for line in lines {
            // Skip lines that are clearly not individual items
            if await isLineIndividualItem(line, targetTotal: targetTotal) {
                if let price = extractPriceFromText(line) {
                    if price > 0 && price <= targetTotal {
                        // Extract item name from the line
                        let itemName = extractItemNameFromLine(line, price: price)
                        extractedItems.append((name: itemName, price: price))
                        print("✅ Extracted item: '\(itemName)' - $\(price) from '\(line)'")
                    }
                }
            }
        }
        
        // Keep original order - DO NOT sort
        print("🎯 Final extracted items in order: \(extractedItems.map { "\($0.name): $\($0.price)" })")
        print("📊 Total value: $\(extractedItems.reduce(0) { $0.currencyAdd($1.price) })")
        
        return extractedItems
    }
    
    private func extractPriceFromText(_ text: String) -> Double? {
        // Enhanced price extraction that handles various formats
        let patterns = [
            #"\$?(\d+\.\d{2})"#,         // $12.99 or 12.99
            #"\$?(\d+\.?\d*)"#,          // $12 or 12
        ]
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let priceString = String(text[range])
                    if let price = Double(priceString) {
                        return price
                    }
                }
            }
        }
        return nil
    }
    
    private func extractItemNameFromLine(_ line: String, price: Double) -> String {
        // Remove the price from the line to get the item name
        let priceString = String(format: "%.2f", price)
        let variations = [
            "$\(priceString)",
            priceString,
            String(format: "%.0f", price), // Without decimal if whole number
            "$\(String(format: "%.0f", price))"
        ]
        
        var cleanedLine = line
        
        // Remove price variations from the line
        for variation in variations {
            cleanedLine = cleanedLine.replacingOccurrences(of: variation, with: "")
        }
        
        // Clean up common receipt formatting
        cleanedLine = cleanedLine.replacingOccurrences(of: "  ", with: " ") // Multiple spaces
        cleanedLine = cleanedLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Remove common receipt artifacts
        let cleanupPatterns = [
            #"\s*\d+\s*$"#,  // Trailing numbers (quantity)
            #"^\d+\s*"#,     // Leading numbers (line numbers)
            #"\s*x\d+\s*$"#, // Quantity like "x2"
            #"\s*@\s*\d+.*$"#, // @ price indicators
            #"\s*ea\s*$"#,   // "each" indicators
        ]
        
        for pattern in cleanupPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            cleanedLine = regex.stringByReplacingMatches(
                in: cleanedLine,
                options: [],
                range: NSRange(cleanedLine.startIndex..., in: cleanedLine),
                withTemplate: ""
            )
        }
        
        cleanedLine = cleanedLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // If we have a reasonable name, use it; otherwise create generic name
        if cleanedLine.count >= 2 && cleanedLine.count <= 50 {
            // Capitalize first letter for better presentation
            return cleanedLine.prefix(1).uppercased() + cleanedLine.dropFirst()
        } else {
            // Fallback to price-based name if extraction failed
            return "Item ($\(priceString))"
        }
    }
    
    private func isLineIndividualItem(_ line: String, targetTotal: Double) async -> Bool {
        let lowercased = line.lowercased()
        
        // Exclude lines that are clearly financial summaries
        let excludeKeywords = [
            "total", "subtotal", "sub total", "sub-total",
            "tax", "sales tax", "gst", "hst", "vat",
            "tip", "gratuity", "service charge", "service fee",
            "discount", "coupon", "promo", "promotion",
            "cash", "credit", "card", "payment", "change",
            "balance", "amount due", "due", "owe",
            "receipt", "thank you", "visit", "server"
        ]
        
        // If line contains exclude keywords, it's not an individual item
        for keyword in excludeKeywords {
            if lowercased.contains(keyword) {
                return false
            }
        }
        
        // Must have a price to be considered an item
        guard let price = extractPriceFromText(line), price > 0 else {
            return false
        }
        
        // Price shouldn't be too large compared to target (likely total/subtotal)
        if price > targetTotal * 0.8 {
            return false
        }
        
        // If it has characteristics of a food item, it's likely an individual item
        let foodKeywords = [
            "burger", "pizza", "salad", "sandwich", "drink", "coffee", "tea",
            "chicken", "beef", "fish", "pasta", "rice", "soup", "appetizer",
            "dessert", "cake", "ice cream", "fries", "wings", "taco", "burrito"
        ]
        
        let hasFood = foodKeywords.contains { lowercased.contains($0) }
        if hasFood {
            return true
        }
        
        // If line has reasonable length (not too short, not too long) and has a price, likely an item
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 50
    }
    
    func processWithMathematicalApproach(
        rawText: String,
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async -> [ReceiptItem] {
        print("🧮 Processing with mathematical approach...")
        print("   Target price: $\(confirmedTotal - confirmedTax - confirmedTip)")
        print("   Expected items: \(expectedItemCount)")
        
        // Step 1: Calculate the target price for items (Total - Tax - Tip)
        let targetItemsPrice = confirmedTotal - confirmedTax - confirmedTip
        
        guard targetItemsPrice > 0 else {
            print("❌ Target items price is not positive: $\(targetItemsPrice)")
            return []
        }
        
        // Step 2: Extract all dollar amounts from the receipt, excluding tax/tip
        let allAmounts = extractAllDollarAmounts(text: rawText)
        let taxAmounts = extractTaxAmountsWithRegex(rawText)
        let tipAmounts = extractTipAmountsWithRegex(rawText)
        let excludedAmounts = Set(taxAmounts + tipAmounts + [confirmedTax, confirmedTip])
        
        // Filter out tax/tip amounts from consideration
        let filteredAmounts = allAmounts.filter { !excludedAmounts.contains($0) }
        print("💰 Found \(allAmounts.count) dollar amounts total")
        print("🚫 Excluding tax/tip amounts: \(excludedAmounts)")
        print("✅ Using \(filteredAmounts.count) filtered amounts: \(filteredAmounts)")
        
        // Step 3: Find combination of amounts that sum to target price with confidence
        let (combination, confidenceLevels) = findBestPriceCombinationWithConfidence(
            amounts: filteredAmounts,
            targetSum: targetItemsPrice,
            expectedCount: expectedItemCount
        )
        
        // Step 4: Create items from the combination with confidence levels
        var items: [ReceiptItem] = []
        
        if combination.isEmpty {
            // No perfect combination found - use LLM to extract individual item prices
            print("📝 No perfect combination found, using LLM to extract individual item prices")
            
            // Use Apple Intelligence to specifically extract individual item prices and names with filtering
            let llmExtractedItems = await extractIndividualItemPricesWithFiltering(
                text: rawText,
                targetTotal: targetItemsPrice,
                expectedCount: expectedItemCount,
                excludedAmounts: excludedAmounts
            )
            
            if !llmExtractedItems.isEmpty {
                print("🎯 Using \(llmExtractedItems.count) LLM-extracted items with names")
                
                // Use LLM-extracted items up to expected count (preserve order)
                let usableItems = Array(llmExtractedItems.prefix(expectedItemCount))
                
                for itemData in usableItems {
                    items.append(ReceiptItem(
                        name: itemData.name,
                        price: itemData.price,
                        confidence: .medium,  // Medium confidence - detected but not perfect combination
                        originalDetectedName: itemData.name,
                        originalDetectedPrice: itemData.price
                    ))
                    print("✅ Created item from LLM extraction: '\(itemData.name)' - $\(itemData.price)")
                }
                
                // Fill remaining with placeholders
                let remainingCount = expectedItemCount - usableItems.count
                if remainingCount > 0 {
                    let usedTotal = usableItems.reduce(0) { $0.currencyAdd($1.price) }
                    let remainingTotal = max(0, targetItemsPrice - usedTotal)
                    let avgRemainingPrice = remainingCount > 0 ? remainingTotal / Double(remainingCount) : 0.0
                    
                    print("📝 Adding \(remainingCount) placeholder items for remaining $\(remainingTotal)")
                    
                    for index in usableItems.count..<expectedItemCount {
                        // Give placeholders a suggested price based on remaining amount
                        let suggestedPrice = avgRemainingPrice > 0.50 ? avgRemainingPrice : 0.00
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: suggestedPrice,
                            confidence: .placeholder
                        ))
                    }
                }
            } else {
                // LLM extraction also failed - fall back to basic regex extraction
                print("⚠️ LLM extraction failed, falling back to basic regex extraction")
                
                // Filter out amounts that are likely tax/tip/total to avoid duplication
                let itemAmounts = allAmounts.filter { amount in
                    // Exclude amounts that are too close to tax, tip, or total
                    let taxThreshold = abs(amount - confirmedTax) > 0.50
                    let tipThreshold = abs(amount - confirmedTip) > 0.50
                    let totalThreshold = abs(amount - confirmedTotal) > 0.50
                    return taxThreshold && tipThreshold && totalThreshold && amount <= targetItemsPrice
                }
                
                if !itemAmounts.isEmpty {
                    print("💰 Using \(itemAmounts.count) filtered regex amounts: \(itemAmounts)")
                    
                    // Use detected amounts up to expected count
                    let usableAmounts = Array(itemAmounts.prefix(expectedItemCount))
                    
                    for (index, amount) in usableAmounts.enumerated() {
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: amount,
                            confidence: .low  // Low confidence since even LLM couldn't find good items
                        ))
                        print("✅ Created item from regex fallback: $\(amount)")
                    }
                    
                    // Fill remaining with placeholders
                    let remainingCount = expectedItemCount - usableAmounts.count
                    if remainingCount > 0 {
                        let usedTotal = usableAmounts.reduce(0, +)
                        let remainingTotal = max(0, targetItemsPrice - usedTotal)
                        let avgRemainingPrice = remainingCount > 0 ? remainingTotal / Double(remainingCount) : 0.0
                        
                        print("📝 Adding \(remainingCount) placeholder items for remaining $\(remainingTotal)")
                        
                        for index in usableAmounts.count..<expectedItemCount {
                            let suggestedPrice = avgRemainingPrice > 0.50 ? avgRemainingPrice : 0.00
                            items.append(ReceiptItem(
                                name: "Item \(index + 1)",
                                price: suggestedPrice,
                                confidence: .placeholder
                            ))
                        }
                    }
                } else {
                    // Last resort - create all placeholders with suggested pricing
                    print("📝 No amounts found at all, creating placeholder items with suggested pricing")
                    let avgPrice = targetItemsPrice / Double(expectedItemCount)
                    
                    for index in 0..<expectedItemCount {
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: avgPrice > 0.50 ? avgPrice : 0.00,
                            confidence: .placeholder
                        ))
                    }
                }
            }
        } else {
            // Create items with detected prices and confidence levels
            for (index, price) in combination.enumerated() {
                let confidence = confidenceLevels[index]
                items.append(ReceiptItem(
                    name: "Item \(index + 1)",
                    price: price,
                    confidence: confidence
                ))
            }
            
            // Fill remaining items with placeholders if needed
            let remainingCount = expectedItemCount - combination.count
            if remainingCount > 0 {
                let remainingTotal = max(0, targetItemsPrice - combination.reduce(0, +))
                print("📝 Adding \(remainingCount) placeholder items for remaining $\(remainingTotal)")
                
                for index in combination.count..<expectedItemCount {
                    items.append(ReceiptItem(
                        name: "Item \(index + 1)",
                        price: 0.00,
                        confidence: .placeholder
                    ))
                }
            }
        }
        
        // Step 5: Add tax and tip as separate items if they exist
        if confirmedTax > 0 {
            items.append(ReceiptItem(name: "Tax", price: confirmedTax, confidence: .high))
        }
        if confirmedTip > 0 {
            items.append(ReceiptItem(name: "Tip", price: confirmedTip, confidence: .high))
        }
        
        print("✅ Created \(items.count) items with mathematical approach")
        return items
    }
    
    // MARK: - Item Count Prediction
    
    private func predictItemCount(text: String) async -> Int {
        print("🔢 Predicting item count from OCR text...")
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var itemCount = 0
        var foundFirstPrice = false
        
        for line in lines {
            // Check if line contains financial keywords that end the items section
            if containsFinancialKeyword(line) {
                print("📍 Found financial keyword in: '\(line)' - stopping item count")
                break
            }
            
            // Check if line contains a price
            if let _ = extractPriceFromLine(line) {
                if !foundFirstPrice {
                    foundFirstPrice = true
                    print("💲 Found first price in: '\(line)' - starting item count")
                }
                
                if foundFirstPrice {
                    // Use Apple Intelligence to determine if this is likely an item
                    let isLikelyItem = await analyzeLineForItemCount(line)
                    if isLikelyItem {
                        itemCount += 1
                        print("✅ Counted item: '\(line)'")
                    } else {
                        print("❌ Skipped non-item: '\(line)'")
                    }
                }
            }
        }
        
        print("📈 Predicted item count: \(itemCount)")
        return max(itemCount, 1) // At least 1 item
    }
    
    private func containsFinancialKeyword(_ text: String) -> Bool {
        let financialKeywords = [
            "subtotal", "sub total", "sub-total",
            "total", "amount due", "balance",
            "tax", "sales tax", "tx",
            "tip", "gratuity", "service charge", "grat"
        ]
        
        let lowercased = text.lowercased()
        return financialKeywords.contains { lowercased.contains($0) }
    }
    
    private func analyzeLineForItemCount(_ line: String) async -> Bool {
        // Use simple heuristics for item count prediction
        let lowercased = line.lowercased()
        
        // Skip obvious non-items
        let skipKeywords = [
            "total", "tax", "tip", "gratuity", "subtotal", "balance",
            "cash", "credit", "change", "payment", "receipt"
        ]
        
        for keyword in skipKeywords {
            if lowercased.contains(keyword) {
                return false
            }
        }
        
        // If it has a price and doesn't contain skip keywords, likely an item
        return extractPriceFromLine(line) != nil
    }
    
    // MARK: - Dollar Amount Extraction
    
    private func extractAllDollarAmounts(text: String) -> [Double] {
        let patterns = [
            #"\$(\d+\.?\d*)"#,           // $12.99, $5
            #"(\d+\.\d{2})"#,            // 12.99, 5.00  
            #"(\d+)\s*$"#                // 12 at end of line
        ]
        
        var amounts: [Double] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[range])
                    if let amount = Double(amountString), amount > 0 && amount < 1000 {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        amounts = Array(Set(amounts)).sorted()
        
        print("💵 Extracted amounts: \(amounts)")
        return amounts
    }
    
    // MARK: - Price Combination Logic
    
    private func findBestPriceCombinationWithConfidence(
        amounts: [Double],
        targetSum: Double,
        expectedCount: Int
    ) -> ([Double], [ConfidenceLevel]) {
        print("🎯 Finding best combination for target: $\(targetSum), count: \(expectedCount)")
        
        // Try exact match first (highest confidence)
        if let exact = findExactCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            print("✅ Found exact combination: \(exact)")
            let confidences = Array(repeating: ConfidenceLevel.high, count: exact.count)
            return (exact, confidences)
        }
        
        // Try closest match (medium confidence)
        if let closest = findClosestCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            print("📊 Found closest combination: \(closest)")
            let confidences = Array(repeating: ConfidenceLevel.medium, count: closest.count)
            return (closest, confidences)
        }
        
        // Try flexible count with lower confidence
        for count in (max(1, expectedCount - 2)...(expectedCount + 2)) {
            if let match = findClosestCombination(amounts: amounts, targetSum: targetSum, count: count) {
                print("🔄 Found alternative combination (count \(count)): \(match)")
                let confidences = Array(repeating: ConfidenceLevel.low, count: match.count)
                return (match, confidences)
            }
        }
        
        // No good combination found
        print("⚠️ No good combination found")
        return ([], [])
    }
    
    private func findBestPriceCombination(
        amounts: [Double],
        targetSum: Double,
        expectedCount: Int
    ) -> [Double] {
        print("🎯 Finding best combination for target: $\(targetSum), count: \(expectedCount)")
        
        // Try different combination strategies
        
        // Strategy 1: Exact match with expected count
        if let exact = findExactCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            print("✅ Found exact combination: \(exact)")
            return exact
        }
        
        // Strategy 2: Closest match with expected count
        if let closest = findClosestCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            print("📊 Found closest combination: \(closest)")
            return closest
        }
        
        // Strategy 3: Best match regardless of count (within reasonable range)
        for count in (max(1, expectedCount - 2)...(expectedCount + 2)) {
            if let match = findClosestCombination(amounts: amounts, targetSum: targetSum, count: count) {
                print("🔄 Found alternative combination (count \(count)): \(match)")
                return match
            }
        }
        
        // No fallback - return empty array if no good combination found
        print("⚠️ No good combination found, returning empty array for manual entry")
        return []
    }
    
    private func findExactCombination(amounts: [Double], targetSum: Double, count: Int) -> [Double]? {
        // Use recursive backtracking to find exact combinations
        return findCombinationRecursive(amounts: amounts, targetSum: targetSum, count: count, index: 0, current: [])
    }
    
    private func findCombinationRecursive(
        amounts: [Double],
        targetSum: Double,
        count: Int,
        index: Int,
        current: [Double]
    ) -> [Double]? {
        // Base cases
        if current.count == count {
            let sum = current.reduce(0, +)
            return abs(sum - targetSum) < 0.01 ? current : nil
        }
        
        if index >= amounts.count || current.count > count {
            return nil
        }
        
        // Try including current amount
        if let result = findCombinationRecursive(
            amounts: amounts,
            targetSum: targetSum,
            count: count,
            index: index + 1,
            current: current + [amounts[index]]
        ) {
            return result
        }
        
        // Try skipping current amount
        return findCombinationRecursive(
            amounts: amounts,
            targetSum: targetSum,
            count: count,
            index: index + 1,
            current: current
        )
    }
    
    private func findClosestCombination(amounts: [Double], targetSum: Double, count: Int) -> [Double]? {
        var bestCombination: [Double]?
        var bestDifference = Double.infinity
        
        // Generate all combinations of the specified count
        let combinations = generateCombinations(amounts: amounts, count: count)
        
        for combination in combinations {
            let sum = combination.reduce(0, +)
            let difference = abs(sum - targetSum)
            
            if difference < bestDifference {
                bestDifference = difference
                bestCombination = combination
            }
        }
        
        // Return if the difference is reasonable (within 20% of target)
        if bestDifference <= targetSum * 0.2 {
            return bestCombination
        }
        
        return nil
    }
    
    private func generateCombinations(amounts: [Double], count: Int) -> [[Double]] {
        if count == 0 { return [[]] }
        if amounts.isEmpty { return [] }
        
        var combinations: [[Double]] = []
        
        for i in 0..<amounts.count {
            let remaining = Array(amounts[(i+1)...])
            let subCombinations = generateCombinations(amounts: remaining, count: count - 1)
            
            for subCombination in subCombinations {
                combinations.append([amounts[i]] + subCombination)
            }
        }
        
        return combinations
    }
    
    // MARK: - LLM-based Item Detection for Comparison
    
    func processWithLLMApproach(
        rawText: String,
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async -> [ReceiptItem] {
        print("🤖 Processing with Apple Intelligence approach...")
        
        let targetItemsPrice = confirmedTotal - confirmedTax - confirmedTip
        
        guard targetItemsPrice > 0 else {
            print("❌ Target items price is not positive: $\(targetItemsPrice)")
            return []
        }
        
        let foodItems = await extractItemsWithAppleIntelligence(
            text: rawText,
            targetPrice: targetItemsPrice,
            expectedCount: expectedItemCount
        )
        
        // Add tax and tip items to Apple Intelligence results for complete receipt view
        var allItems = foodItems
        
        if confirmedTax > 0 {
            allItems.append(ReceiptItem(
                name: "Tax",
                price: confirmedTax,
                confidence: .high,
                originalDetectedName: "Tax",
                originalDetectedPrice: confirmedTax
            ))
        }
        
        if confirmedTip > 0 {
            allItems.append(ReceiptItem(
                name: "Tip", 
                price: confirmedTip,
                confidence: .high,
                originalDetectedName: "Tip",
                originalDetectedPrice: confirmedTip
            ))
        }
        
        return allItems
    }
    
    // Enhanced Apple Intelligence extraction for LLM comparison
    private func extractItemsWithAppleIntelligence(
        text: String,
        targetPrice: Double,
        expectedCount: Int
    ) async -> [ReceiptItem] {
        print("🧠 Using Apple Intelligence for enhanced item extraction...")
        
        // First extract and exclude tax/tip amounts to avoid including them as item prices
        let (taxAmounts, tipAmounts) = await extractTaxTipAmountsForFiltering(text: text)
        let excludedAmounts = Set(taxAmounts + tipAmounts)
        print("🚫 Excluding tax/tip amounts from item detection: \(excludedAmounts)")
        
        // NEW APPROACH: Match item names with prices using intelligent pairing
        let detectedItems = await extractItemsUsingNamePricePairing(
            text: text, 
            targetPrice: targetPrice, 
            expectedCount: expectedCount,
            excludedAmounts: excludedAmounts
        )
        
        print("✅ Apple Intelligence extracted \(detectedItems.count) items")
        return detectedItems
    }
    
    // Parse item names from lines containing dollar amounts, preserving exact order
    private func extractItemsUsingNamePricePairing(
        text: String,
        targetPrice: Double, 
        expectedCount: Int,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Step 1: Find the first line that contains a dollar amount - this is where items start
        var firstDollarLineIndex: Int? = nil
        
        for (index, line) in lines.enumerated() {
            if extractPriceFromLine(line) != nil {
                firstDollarLineIndex = index
                print("💰 Found first dollar amount at line \(index): '\(line)'")
                break
            }
        }
        
        guard let startIndex = firstDollarLineIndex else {
            print("❌ No dollar amounts found in receipt")
            return []
        }
        
        // Step 2: Extract item section starting from first dollar amount line
        let itemSection = Array(lines[startIndex...])
        print("📋 Processing item section (\(itemSection.count) lines) starting from first dollar amount:")
        for (relativeIndex, line) in itemSection.enumerated() {
            print("   Line \(startIndex + relativeIndex): '\(line)'")
        }
        
        // Step 3: Use Apple Intelligence to parse items WITH dollar amounts included
        let itemsWithPrices = await parseItemNamesAndPricesWithAppleIntelligence(
            itemSection: itemSection, 
            excludedAmounts: excludedAmounts,
            targetPrice: targetPrice,
            expectedCount: expectedCount
        )
        
        print("📊 Apple Intelligence extracted \(itemsWithPrices.count) items with names and prices")
        return itemsWithPrices
    }
    
    // Use Apple Intelligence to parse item names and prices while preserving order
    private func parseItemNamesAndPricesWithAppleIntelligence(
        itemSection: [String],
        excludedAmounts: Set<Double>,
        targetPrice: Double,
        expectedCount: Int
    ) async -> [ReceiptItem] {
        
        print("🧠 Using Apple Intelligence to parse items with preserved order...")
        
        var extractedItems: [ReceiptItem] = []
        
        // Process each line in order to preserve receipt sequence
        for (index, line) in itemSection.enumerated() {
            guard !line.isEmpty else { continue }
            
            // Skip financial summary lines
            if shouldSkipLineForIntelligentAnalysis(line) {
                print("🚫 Skipping financial line: '\(line)'")
                continue
            }
            
            // Extract price from this line
            guard let price = extractPriceFromLine(line) else { continue }
            
            // Skip excluded tax/tip amounts  
            if excludedAmounts.contains(price) {
                print("🚫 Skipping excluded amount $\(price): '\(line)'")
                continue
            }
            
            // Skip prices that are too high (likely totals)
            if price > targetPrice {
                print("🚫 Skipping price too high $\(price): '\(line)'")
                continue
            }
            
            // Parse item name from this line or previous line
            let itemName = await extractItemNameFromLineWithPrice(
                currentLine: line,
                previousLine: index > 0 ? itemSection[index - 1] : nil,
                price: price
            )
            
            let receiptItem = ReceiptItem(
                name: itemName,
                price: price,
                confidence: .high,
                originalDetectedName: itemName,
                originalDetectedPrice: price
            )
            
            extractedItems.append(receiptItem)
            print("✅ Extracted item \(extractedItems.count): '\(itemName)' - $\(price)")
            
            // Stop when we reach expected count
            if extractedItems.count >= expectedCount {
                break
            }
        }
        
        return extractedItems
    }
    
    // Extract item name from current line with price, or previous line if needed
    private func extractItemNameFromLineWithPrice(
        currentLine: String,
        previousLine: String?,
        price: Double
    ) async -> String {
        
        print("🔍 Extracting name from current line: '\(currentLine)' (price: $\(price))")
        if let prev = previousLine {
            print("🔍 Previous line available: '\(prev)'")
        }
        
        // Try to extract name from current line first
        if let nameFromCurrent = extractItemNameWithEnhancedAppleIntelligence(line: currentLine, price: price) {
            if nameFromCurrent.count > 3 && !nameFromCurrent.hasPrefix("Item ") {
                return nameFromCurrent
            }
        }
        
        // If current line doesn't have a good name, try previous line
        if let previousLine = previousLine,
           await isLikelyItemDescription(previousLine) {
            print("🔄 Using previous line for item name: '\(previousLine)'")
            return previousLine
        }
        
        // Fallback: try to extract any meaningful text from current line
        let fallbackName = currentLine
            .replacingOccurrences(of: String(format: "$%.2f", price), with: "")
            .replacingOccurrences(of: String(format: "%.2f", price), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !fallbackName.isEmpty && fallbackName.count > 2 {
            print("🔄 Using fallback name: '\(fallbackName)'")
            return fallbackName
        }
        
        // Last resort
        return "Menu Item $\(String(format: "%.2f", price))"
    }
    
    // Check if a line contains an item description (has meaningful text content)
    private func isLikelyItemDescription(_ line: String) async -> Bool {
        // Skip lines that are clearly not item descriptions
        let excludePatterns = [
            "subtotal", "tax", "total", "cash", "change", "visa", "mastercard", "card",
            "approval", "entry mode", "account", "acct", "cashier", "order", "receipt"
        ]
        
        let lowercaseLine = line.lowercased()
        for pattern in excludePatterns {
            if lowercaseLine.contains(pattern) {
                return false
            }
        }
        
        // Must contain letters (not just numbers)
        guard line.rangeOfCharacter(from: CharacterSet.letters) != nil else { return false }
        
        // Should have some meaningful length
        guard line.count >= 3 else { return false }
        
        // Use Apple Intelligence Natural Language to check if it looks like a product description
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line
        
        var hasNounsOrFood = false
        
        tagger.enumerateTags(in: line.startIndex..<line.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            
            let word = String(line[range])
            
            if let tag = tag {
                switch tag {
                case .noun, .adjective:
                    hasNounsOrFood = true
                case .other:
                    // Check if it might be a food-related word
                    if isLikelyFoodWordSync(word) {
                        hasNounsOrFood = true
                    }
                default:
                    break
                }
            } else {
                // Even if NL can't classify it, check if it looks like food
                if isLikelyFoodWordSync(word) {
                    hasNounsOrFood = true
                }
            }
            
            return true
        }
        
        return hasNounsOrFood
    }
    
    private func analyzeLineForItemWithAppleIntelligence(_ line: String, targetPrice: Double, excludedAmounts: Set<Double>) async -> Bool {
        // Use Natural Language processing to determine if this is likely a food item
        guard let price = extractPriceFromLine(line) else { return false }
        
        // Skip if this price is a known tax/tip amount
        if excludedAmounts.contains(price) {
            print("🚫 Skipping price $\(price) as it's a tax/tip amount")
            return false
        }
        
        let hasItemName = isLikelyProductName(line.replacingOccurrences(of: "\\$[0-9.]+", with: "", options: .regularExpression))
        
        return hasItemName
    }
    
    private func parseItemLineWithAppleIntelligence(_ line: String, lineIndex: Int, excludedAmounts: Set<Double>) async -> ReceiptItem? {
        guard let price = extractPriceFromLine(line) else { return nil }
        
        // Skip if this price is a known tax/tip amount
        if excludedAmounts.contains(price) {
            print("🚫 Skipping item creation for price $\(price) as it's a tax/tip amount")
            return nil
        }
        
        // Extract item name using enhanced Apple Intelligence
        let itemName = extractItemNameWithEnhancedAppleIntelligence(line: line, price: price) ?? "Item \(lineIndex + 1)"
        
        return ReceiptItem(
            name: itemName,
            price: price,
            confidence: .high,
            originalDetectedName: itemName,
            originalDetectedPrice: price
        )
    }
    
    // Extract tax and tip amounts for filtering purposes
    private func extractTaxTipAmountsForFiltering(text: String) async -> ([Double], [Double]) {
        let taxAmounts = extractTaxAmountsWithRegex(text)
        let tipAmounts = extractTipAmountsWithRegex(text)
        
        print("📊 Found tax amounts for filtering: \(taxAmounts)")
        print("📊 Found tip amounts for filtering: \(tipAmounts)")
        
        return (taxAmounts, tipAmounts)
    }
    
    // Enhanced item name extraction using Apple Intelligence
    private func extractItemNameWithEnhancedAppleIntelligence(line: String, price: Double) -> String? {
        print("🔍 Enhanced Apple Intelligence analyzing line: '\(line)' with price: $\(price)")
        
        var cleanedLine = line
        
        // Remove the specific price value patterns
        let specificPricePatterns = [
            String(format: "$%.2f", price),
            String(format: "%.2f$", price), 
            String(format: "$ %.2f", price),
            String(format: "%.2f $", price),
            String(format: " %.2f", price) + "$",
            "$" + String(format: " %.2f", price),
            String(format: "%.2f", price) // Also try without currency symbol
        ]
        
        for pattern in specificPricePatterns {
            cleanedLine = cleanedLine.replacingOccurrences(of: pattern, with: " ")
        }
        
        // Clean up extra spaces and basic formatting
        cleanedLine = cleanedLine.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleanedLine = cleanedLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 After price removal: '\(cleanedLine)'")
        
        // If we have any meaningful text left, return it
        if !cleanedLine.isEmpty {
            let words = cleanedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Accept any text that has at least one non-purely-numeric word
            let hasValidContent = words.contains { word in
                // Accept words with letters, mixed alphanumeric, or single characters
                return word.rangeOfCharacter(from: CharacterSet.letters) != nil || 
                       (word.count >= 2 && !word.allSatisfy(\.isWholeNumber))
            }
            
            if hasValidContent {
                let finalName = cleanedLine
                print("✅ Extracted item name: '\(finalName)' from line: '\(line)'")
                return finalName
            }
        }
        
        // If price removal left us with nothing useful, try using the original line minus just numbers at the end
        let fallbackName = line.replacingOccurrences(of: #"\s*\$?\d+\.?\d*\$?\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !fallbackName.isEmpty && fallbackName.count >= 2 {
            print("🔄 Using fallback extraction: '\(fallbackName)' from line: '\(line)'")
            return fallbackName
        }
        
        // Last resort: return the original line if it has any non-numeric content
        if line.rangeOfCharacter(from: CharacterSet.letters) != nil {
            print("🆘 Last resort: using original line '\(line)'")
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("❌ No meaningful item name found in line: '\(line)'")
        return nil
    }
    
    // Helper method to enhance item names using Natural Language processing
    private func enhanceItemNameWithNaturalLanguage(_ text: String) async -> String? {
        // Use NLTagger to identify if we can improve the text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var words: [String] = []
        
        // Extract words, preserving structure but identifying meaningful parts
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            
            let word = String(text[range])
            
            // Include most words, but enhance known food/product patterns
            if word.count >= 1 {
                words.append(word)
            }
            
            return true
        }
        
        // If NL processing gives us something useful, return it; otherwise return original
        let processedName = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return processedName.isEmpty ? nil : processedName
    }
    
    private func isLikelyFoodWordSync(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        let foodKeywords = [
            // Food categories
            "sandwich", "burger", "pizza", "pasta", "salad", "soup", "chicken", "beef",
            "fish", "shrimp", "bacon", "cheese", "bread", "rice", "noodles", "wrap",
            "taco", "burrito", "wings", "fries", "onion", "mushroom", "pepper", "tomato",
            
            // Beverages
            "coffee", "tea", "soda", "juice", "water", "beer", "wine", "latte", "cappuccino",
            "smoothie", "shake", "cola", "sprite", "pepsi", "coke",
            
            // Cooking methods
            "grilled", "fried", "baked", "roasted", "steamed", "sauteed", "crispy", "fresh",
            
            // Portions and styles
            "large", "small", "medium", "regular", "special", "classic", "deluxe", "combo"
        ]
        
        return foodKeywords.contains { lowercased.contains($0) }
    }
    
    private func aggressiveItemExtractionWithAppleIntelligence(
        text: String,
        existingItems: [ReceiptItem],
        targetCount: Int,
        targetPrice: Double,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var additionalCandidates: [(lineIndex: Int, item: ReceiptItem)] = []
        let usedPrices = Set(existingItems.map { $0.price })
        
        for (index, line) in lines.enumerated() {
            guard additionalCandidates.count < (targetCount - existingItems.count) else { break }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Look for any price that hasn't been used and isn't tax/tip
            if let price = extractPriceFromLine(trimmedLine),
               !usedPrices.contains(price),
               !excludedAmounts.contains(price),
               price <= targetPrice {
                
                let itemName = extractItemNameWithEnhancedAppleIntelligence(line: trimmedLine, price: price) ?? "Item \(existingItems.count + additionalCandidates.count + 1)"
                
                let item = ReceiptItem(
                    name: itemName,
                    price: price,
                    confidence: .medium,
                    originalDetectedName: itemName,
                    originalDetectedPrice: price
                )
                
                additionalCandidates.append((lineIndex: index, item: item))
            }
        }
        
        // Sort by line order to preserve receipt order
        return additionalCandidates.sorted { $0.lineIndex < $1.lineIndex }.map { $0.item }
    }
}

// MARK: - Bill Split Session Management
class BillSplitSession: ObservableObject {
    // OCR Results
    @Published var scannedItems: [ReceiptItem] = []
    @Published var rawReceiptText: String = ""
    @Published var ocrConfidence: Float = 0.0
    @Published var identifiedTotal: Double? = nil
    @Published var capturedReceiptImage: UIImage? = nil
    
    // Comparison Results - Regex vs LLM
    @Published var regexDetectedItems: [ReceiptItem] = []
    @Published var llmDetectedItems: [ReceiptItem] = []
    @Published var confirmedTax: Double = 0.0
    @Published var confirmedTip: Double = 0.0
    @Published var confirmedTotal: Double = 0.0
    @Published var expectedItemCount: Int = 0
    
    // Participants
    @Published var participants: [UIParticipant] = [
        UIParticipant(id: 1, name: "You", color: .blue) // Always start with "You"
    ]
    
    // Bill payer selection (mandatory for bill creation)
    @Published var paidByParticipantID: Int? = nil
    
    // Bill name (optional, defaults to item count description)
    @Published var billName: String = ""
    
    // Item assignments
    @Published var assignedItems: [UIItem] = []
    
    // Session state
    @Published var sessionState: SessionState = .home
    @Published var isSessionActive: Bool = false
    
    enum SessionState {
        case home
        case scanning
        case assigning
        case reviewing
        case complete
    }
    
    let colors: [Color] = [.blue, .green, .purple, .pink, .yellow, .red, .orange, .cyan, .teal, .mint]
    
    func startNewSession() {
        print("🆕 Starting new bill split session")
        resetSession()
        isSessionActive = true
        sessionState = .scanning
    }
    
    func resetSession() {
        print("🔄 Resetting bill split session")
        print("   - Previous regexDetectedItems count: \(regexDetectedItems.count)")
        print("   - Previous llmDetectedItems count: \(llmDetectedItems.count)")
        print("   - Previous confirmedTotal: \(confirmedTotal)")
        
        scannedItems.removeAll()
        rawReceiptText = ""
        ocrConfidence = 0.0
        identifiedTotal = nil
        capturedReceiptImage = nil
        
        // Clear comparison results
        regexDetectedItems.removeAll()
        llmDetectedItems.removeAll()
        confirmedTax = 0.0
        confirmedTip = 0.0
        confirmedTotal = 0.0
        expectedItemCount = 0
        
        print("✅ Session reset complete - all state cleared")
        
        // Keep "You" but remove other participants
        participants = [UIParticipant(id: 1, name: "You", color: .blue)]
        assignedItems.removeAll()
        
        // Reset bill payer selection and name
        paidByParticipantID = nil
        billName = ""
        
        sessionState = .home
        isSessionActive = false
    }
    
    func updateOCRResults(_ items: [ReceiptItem], rawText: String, confidence: Float, identifiedTotal: Double?, suggestedAmounts: [Double] = [], image: UIImage? = nil, confirmedTax: Double = 0, confirmedTip: Double = 0, confirmedTotal: Double = 0, expectedItemCount: Int = 0) {
        print("📄 Updating OCR results: \(items.count) items, confidence: \(confidence), identifiedTotal: \(identifiedTotal ?? 0)")
        print("💡 Suggested amounts for quick entry: \(suggestedAmounts)")
        
        scannedItems = items
        rawReceiptText = rawText
        ocrConfidence = confidence
        self.identifiedTotal = identifiedTotal
        self.capturedReceiptImage = image
        
        // Store confirmed values for dual processing
        self.confirmedTax = confirmedTax
        self.confirmedTip = confirmedTip
        self.confirmedTotal = confirmedTotal > 0 ? confirmedTotal : identifiedTotal ?? 0
        self.expectedItemCount = expectedItemCount
        
        // Convert ReceiptItems to UIItems for the assign screen
        assignedItems = items.enumerated().map { index, receiptItem in
            UIItem(
                id: index + 1,
                name: receiptItem.name,
                price: receiptItem.price,
                assignedTo: nil,  // Legacy: Start unassigned
                assignedToParticipants: Set<Int>(), // New: Start with no participants
                confidence: receiptItem.confidence,
                originalDetectedName: receiptItem.originalDetectedName,
                originalDetectedPrice: receiptItem.originalDetectedPrice
            )
        }
        
        print("✅ Converted \(items.count) ReceiptItems to UIItems for assignment")
        
        // Go directly to assignment screen
        sessionState = .assigning
    }
    
    func addParticipant(name: String) -> UIParticipant? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return nil }
        
        // Check for duplicates (case-insensitive)
        if participants.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            print("⚠️ Participant \(trimmedName) already exists")
            return nil
        }
        
        let newId = (participants.map { $0.id }.max() ?? 0) + 1
        let colorIndex = participants.count % colors.count
        
        let newParticipant = UIParticipant(
            id: newId,
            name: trimmedName,
            color: colors[colorIndex]
        )
        
        participants.append(newParticipant)
        print("✅ Added participant: \(trimmedName)")
        return newParticipant
    }
    
    func addParticipantWithValidation(name: String, email: String? = nil, phoneNumber: String? = nil, authViewModel: AuthViewModel, contactsManager: ContactsManager? = nil) async -> (participant: UIParticipant?, error: String?, needsContact: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { 
            return (nil, "Name cannot be empty", false)
        }
        
        // Check if trying to add yourself
        if trimmedName.lowercased() == "you" {
            print("⚠️ Cannot add yourself - already in bill")
            return (nil, "You are already in this bill", false)
        }
        
        // Check if email matches current user's email
        if let email = email {
            let currentUserEmail = await MainActor.run { authViewModel.user?.email }
            if let currentUserEmail = currentUserEmail {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let validEmail = emailValidation.sanitized {
                    if validEmail.lowercased() == currentUserEmail.lowercased() {
                        print("⚠️ Cannot add your own email - already in bill")
                        return (nil, "You are already in this bill", false)
                    }
                }
            }
        }
        
        // Check for duplicates (case-insensitive)
        if participants.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            print("⚠️ Participant \(trimmedName) already exists")
            return (nil, "Participant already exists", false)
        }
        
        // SECURITY: First validate user is registered with SplitSmart
        let isOnboarded = await authViewModel.isUserOnboarded(email: email, phoneNumber: phoneNumber)
        
        if !isOnboarded {
            print("❌ User \(trimmedName) is not onboarded to SplitSmart")
            return (nil, "User is not registered with SplitSmart. Only registered users can be added to bills.", false)
        }
        
        // Splitwise-style: Check if email is in user's transaction history
        if let email = email, let contactsManager = contactsManager {
            let emailValidation = AuthViewModel.validateEmail(email)
            if emailValidation.isValid, let validEmail = emailValidation.sanitized {
                // Check if this email is already in user's transaction contacts
                let existingTransactionContact = contactsManager.transactionContacts.first { 
                    $0.email.lowercased() == validEmail.lowercased() 
                }
                
                if existingTransactionContact == nil {
                    // Email not in transaction history but is registered - show "add to your network" modal
                    print("📝 Registered email \(validEmail) not in user's transaction history - showing add to network")
                    return (nil, "Add \(validEmail) to your SplitSmart network", true)
                } else {
                    // Email found in transaction history - proceed with normal flow
                    print("📋 Email \(validEmail) found in transaction history as: \(existingTransactionContact?.displayName ?? "Unknown")")
                }
            }
        }
        
        let newId = (participants.map { $0.id }.max() ?? 0) + 1
        let colorIndex = participants.count % colors.count
        
        let newParticipant = UIParticipant(
            id: newId,
            name: trimmedName,
            color: colors[colorIndex]
        )
        
        participants.append(newParticipant)
        print("✅ Added validated participant: \(trimmedName)")
        return (newParticipant, nil, false)
    }
    
    func removeParticipant(_ participant: UIParticipant) {
        // Don't allow removing "You"
        guard participant.name != "You" else { return }
        
        // Remove from participants
        participants.removeAll { $0.id == participant.id }
        
        // Unassign any items assigned to this participant
        for index in assignedItems.indices {
            // Legacy assignment cleanup
            if assignedItems[index].assignedTo == participant.id {
                assignedItems[index].assignedTo = nil
            }
            // New multiple assignment cleanup
            assignedItems[index].assignedToParticipants.remove(participant.id)
        }
        
        print("🗑️ Removed participant: \(participant.name)")
    }
    
    func assignItem(itemId: Int, to participantId: Int?) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedTo = participantId
            
            let participantName = participants.first { $0.id == participantId }?.name ?? "Unassigned"
            print("📝 Assigned \(assignedItems[index].name) to \(participantName)")
        }
    }
    
    // MARK: - Multiple Participant Assignment Methods
    
    func addParticipantToItem(itemId: Int, participantId: Int) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedToParticipants.insert(participantId)
            
            let participantName = participants.first { $0.id == participantId }?.name ?? "Unknown"
            print("➕ Added \(participantName) to \(assignedItems[index].name)")
        }
    }
    
    func removeParticipantFromItem(itemId: Int, participantId: Int) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedToParticipants.remove(participantId)
            
            let participantName = participants.first { $0.id == participantId }?.name ?? "Unknown"
            print("➖ Removed \(participantName) from \(assignedItems[index].name)")
        }
    }
    
    func updateItemAssignments(_ updatedItem: UIItem) {
        if let index = assignedItems.firstIndex(where: { $0.id == updatedItem.id }) {
            assignedItems[index] = updatedItem
            print("🔄 Updated assignments for \(updatedItem.name)")
        }
    }
    
    func completeAssignment() {
        sessionState = .reviewing
        
        // Auto-assign shared items (Tax, Tip) equally
        splitSharedItems()
    }
    
    private func splitSharedItems() {
        for index in assignedItems.indices {
            if assignedItems[index].assignedTo == nil && 
               (assignedItems[index].name.lowercased().contains("tax") || 
                assignedItems[index].name.lowercased().contains("tip")) {
                assignedItems[index].name += " (Split equally)"
            }
        }
    }
    
    func completeSession() {
        sessionState = .complete
        print("🎉 Bill split session completed")
    }
    
    // MARK: - Dual Processing Methods
    
    func processWithBothApproaches(
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async {
        print("🔄 Processing with both regex and LLM approaches...")
        
        await MainActor.run {
            self.confirmedTax = confirmedTax
            self.confirmedTip = confirmedTip
            self.confirmedTotal = confirmedTotal
            self.expectedItemCount = expectedItemCount
        }
        
        let ocrService = OCRService()
        
        // Process with regex approach (current mathematical approach)
        await MainActor.run {
            print("📊 Starting regex processing...")
        }
        
        let regexItems = await ocrService.processWithMathematicalApproach(
            rawText: rawReceiptText,
            confirmedTax: confirmedTax,
            confirmedTip: confirmedTip,
            confirmedTotal: confirmedTotal,
            expectedItemCount: expectedItemCount
        )
        
        await MainActor.run {
            self.regexDetectedItems = regexItems
            print("✅ Regex processing complete: \(regexItems.count) items")
        }
        
        // Process with LLM approach
        await MainActor.run {
            print("🤖 Starting LLM processing...")
        }
        
        let llmItems = await ocrService.processWithLLMApproach(
            rawText: rawReceiptText,
            confirmedTax: confirmedTax,
            confirmedTip: confirmedTip,
            confirmedTotal: confirmedTotal,
            expectedItemCount: expectedItemCount
        )
        
        await MainActor.run {
            self.llmDetectedItems = llmItems
            print("✅ LLM processing complete: \(llmItems.count) items")
        }
    }
    
    // MARK: - Summary Data
    var totalAmount: Double {
        assignedItems.reduce(0) { $0.currencyAdd($1.price) }
    }
    
    /// Checks if the session is ready for bill creation
    var isReadyForBillCreation: Bool {
        // Must have assigned items
        guard !assignedItems.isEmpty else { 
            print("❌ isReadyForBillCreation: No assigned items")
            return false 
        }
        
        // All items must be assigned to participants
        let allItemsAssigned = assignedItems.allSatisfy { !$0.assignedToParticipants.isEmpty }
        guard allItemsAssigned else { 
            print("❌ isReadyForBillCreation: Not all items assigned to participants")
            return false 
        }
        
        // Must have selected who paid the bill
        guard paidByParticipantID != nil else { 
            print("❌ isReadyForBillCreation: No paidBy participant selected")
            return false 
        }
        
        // Must have at least 2 participants (including "You")
        guard participants.count >= 2 else { 
            print("❌ isReadyForBillCreation: Need at least 2 participants, have \(participants.count)")
            return false 
        }
        
        print("✅ isReadyForBillCreation: All validations passed")
        return true
    }
    
    /// Calculates individual debts - how much each participant owes to the person who paid
    var individualDebts: [String: Double] {
        guard let paidByID = paidByParticipantID else { return [:] }
        
        var debts: [String: Double] = [:]
        
        // Initialize all participants (except the payer) with $0 debt
        for participant in participants {
            if participant.id != paidByID {
                debts[String(participant.id)] = 0.0
            }
        }
        
        // Calculate debt for each item
        for item in assignedItems {
            guard !item.assignedToParticipants.isEmpty else { continue }
            
            let participantCount = item.assignedToParticipants.count
            let baseAmount = item.price / Double(participantCount)
            let roundedBase = (baseAmount * 100).rounded() / 100
            
            // Handle remainder distribution (like in BillCalculator)
            let totalRounded = roundedBase * Double(participantCount)
            let remainder = item.price - totalRounded
            let remainderCents = Int((remainder * 100).rounded())
            
            // Sort participant IDs for consistent remainder distribution
            let sortedParticipants = Array(item.assignedToParticipants).sorted()
            
            for (index, participantID) in sortedParticipants.enumerated() {
                if participantID != paidByID {
                    var amountOwed = roundedBase
                    
                    // Add extra cent to first few participants to handle remainder
                    if index < remainderCents {
                        amountOwed += 0.01
                    }
                    
                    let participantKey = String(participantID)
                    debts[participantKey] = (debts[participantKey] ?? 0.0) + amountOwed
                }
            }
        }
        
        // Final rounding to ensure 2 decimal places
        for participantKey in debts.keys {
            debts[participantKey] = ((debts[participantKey] ?? 0.0) * 100).rounded() / 100
        }
        
        return debts
    }
    
    var participantSummaries: [UISummaryParticipant] {
        return participants.enumerated().map { index, participant in
            // Calculate total owed using smart distribution for exact amounts
            let totalOwed = assignedItems.reduce(0.0) { total, item in
                return total.currencyAdd(item.getCostForParticipant(participantId: participant.id))
            }
            
            return UISummaryParticipant(
                id: participant.id,
                name: participant.name,
                color: participant.color,
                owes: participant.name == "You" ? 0.0 : totalOwed.currencyRounded,
                gets: participant.name == "You" ? 0.0 : 0.0 // Others don't "get" money, they owe it
            )
        }
    }
    
    var breakdownSummaries: [UIBreakdown] {
        return participants.map { participant in
            // Create breakdown items using smart distribution for exact amounts
            let items = assignedItems.compactMap { item -> UIBreakdownItem? in
                let cost = item.getCostForParticipant(participantId: participant.id)
                if cost > 0 {
                    return UIBreakdownItem(name: item.name, price: cost)
                }
                return nil
            }
            
            return UIBreakdown(
                id: participant.id,
                name: participant.name,
                color: participant.color,
                items: items
            )
        }
    }
}

// MARK: - Transaction Contacts Manager (Splitwise-style)
class ContactsManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var transactionContacts: [TransactionContact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentUserId: String?
    private var contactsListener: ListenerRegistration?
    
    init() {}
    
    func setCurrentUser(_ userId: String) {
        // Clear existing data if switching users
        if let currentUser = self.currentUserId, currentUser != userId {
            print("🔄 Switching users from \(currentUser) to \(userId) - clearing contacts")
            // Remove old listener
            contactsListener?.remove()
            contactsListener = nil
            self.transactionContacts = []
            self.errorMessage = nil
        }
        
        self.currentUserId = userId
        loadTransactionContacts()
    }
    
    func clearCurrentUser() {
        print("🧹 Clearing ContactsManager data on logout")
        // Remove listener
        contactsListener?.remove()
        contactsListener = nil
        self.currentUserId = nil
        self.transactionContacts = []
        self.errorMessage = nil
        self.isLoading = false
    }
    
    func loadTransactionContacts() {
        guard let userId = currentUserId else { return }
        
        // Remove any existing listener first
        contactsListener?.remove()
        
        isLoading = true
        
        print("📡 Loading transaction contacts for user: \(userId)")
        contactsListener = db.collection("users").document(userId).collection("transactionContacts")
            .order(by: "lastTransactionAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ Failed to load transaction contacts: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load transaction contacts: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No documents found in transaction contacts")
                        self?.transactionContacts = []
                        return
                    }
                    
                    print("📊 Found \(documents.count) transaction contact documents")
                    let contacts = documents.compactMap { doc in
                        do {
                            let contact = try doc.data(as: TransactionContact.self)
                            print("✅ Loaded contact: \(contact.displayName) (\(contact.email))")
                            return contact
                        } catch {
                            print("❌ Failed to decode contact document \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    self?.transactionContacts = contacts
                    print("📋 Total transaction contacts loaded: \(contacts.count)")
                }
            }
    }
    
    func saveTransactionContact(_ contact: TransactionContact) async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "ContactsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if contact already exists
        let existingContact = transactionContacts.first { $0.email.lowercased() == contact.email.lowercased() }
        
        if let existing = existingContact {
            // Update existing contact - increment transaction count and update timestamp
            let newTotalTransactions = existing.totalTransactions + 1
            
            try await db.collection("users").document(userId).collection("transactionContacts")
                .document(existing.id).updateData([
                    "lastTransactionAt": FieldValue.serverTimestamp(),
                    "totalTransactions": newTotalTransactions
                ])
            
            print("✅ Updated existing transaction contact: \(existing.displayName)")
        } else {
            // Save new transaction contact
            try db.collection("users").document(userId).collection("transactionContacts").document(contact.id).setData(from: contact)
            
            print("✅ Saved new transaction contact: \(contact.displayName) (\(contact.email))")
        }
    }
    
    func searchTransactionContacts(query: String) -> [TransactionContact] {
        guard !query.isEmpty else { return transactionContacts }
        
        let lowercaseQuery = query.lowercased()
        return transactionContacts.filter {
            $0.displayName.lowercased().contains(lowercaseQuery) ||
            $0.email.lowercased().contains(lowercaseQuery) ||
            ($0.nickname?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    func validateNewTransactionContact(displayName: String, email: String, phoneNumber: String?, authViewModel: AuthViewModel) async -> ContactValidationResult {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate display name
        guard !trimmedName.isEmpty else {
            return ContactValidationResult(isValid: false, error: "Name is required", contact: nil)
        }
        
        guard trimmedName.count >= 2 else {
            return ContactValidationResult(isValid: false, error: "Name must be at least 2 characters", contact: nil)
        }
        
        // Validate email
        let emailValidation = AuthViewModel.validateEmail(trimmedEmail)
        guard emailValidation.isValid, let validEmail = emailValidation.sanitized else {
            return ContactValidationResult(isValid: false, error: emailValidation.error ?? "Invalid email format", contact: nil)
        }
        
        // SECURITY: Check if this email is a registered SplitSmart user
        let isOnboarded = await authViewModel.isUserOnboarded(email: validEmail, phoneNumber: nil)
        guard isOnboarded else {
            return ContactValidationResult(isValid: false, error: "This email is not registered with SplitSmart. Only registered users can be added to bills.", contact: nil)
        }
        
        // Check if this is the current user's own email
        let currentUserEmail = await MainActor.run { authViewModel.user?.email }
        if let currentUserEmail = currentUserEmail, 
           validEmail.lowercased() == currentUserEmail.lowercased() {
            return ContactValidationResult(isValid: false, error: "You cannot add yourself as a contact.", contact: nil)
        }
        
        // Validate phone number if provided
        var validPhone: String?
        if let phone = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            let phoneValidation = AuthViewModel.validatePhoneNumber(phone)
            if phoneValidation.isValid {
                validPhone = phoneValidation.sanitized
            } else {
                return ContactValidationResult(isValid: false, error: phoneValidation.error ?? "Invalid phone number format", contact: nil)
            }
        }
        
        let newContact = TransactionContact(
            displayName: trimmedName,
            email: validEmail,
            phoneNumber: validPhone,
            contactUserId: nil // Not implementing global user lookup for now
        )
        
        return ContactValidationResult(isValid: true, error: nil, contact: newContact)
    }
}