import Foundation
import FirebaseFirestore

// MARK: - Bill Settlement Data Models

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
    let createdByDisplayName: String // Snapshot for UI
    let createdByEmail: String // Snapshot for notifications
    let lastModifiedBy: String?
    let lastModifiedAt: Timestamp?
    
    // Financial reconciliation
    let calculatedTotals: [String: Double] // userID: amount owed to paidBy
    let roundingAdjustments: [String: Double] // Track penny distributions
    
    // Deletion status
    var isDeleted: Bool
    
    init(id: String = UUID().uuidString,
         createdBy: String,
         createdByDisplayName: String,
         createdByEmail: String,
         paidBy: String,
         paidByDisplayName: String,
         paidByEmail: String,
         billName: String?,
         totalAmount: Double,
         currency: String = "USD",
         date: Timestamp = Timestamp(),
         createdAt: Timestamp = Timestamp(),
         items: [BillItem],
         participants: [BillParticipant],
         participantIds: [String]? = nil,
         calculatedTotals: [String: Double]? = nil,
         roundingAdjustments: [String: Double] = [:],
         isDeleted: Bool = false) {
        self.id = id
        self.createdBy = createdBy
        self.createdByDisplayName = createdByDisplayName
        self.createdByEmail = createdByEmail
        self.paidBy = paidBy
        self.paidByDisplayName = paidByDisplayName
        self.paidByEmail = paidByEmail
        self.billName = billName
        self.totalAmount = totalAmount
        self.currency = currency
        self.date = date
        self.createdAt = createdAt
        self.items = items
        self.participants = participants
        self.participantIds = participantIds ?? participants.map { $0.id }
        self.lastModifiedBy = nil
        self.lastModifiedAt = nil
        self.calculatedTotals = calculatedTotals ?? [:]
        self.roundingAdjustments = roundingAdjustments
        self.isDeleted = isDeleted
    }
    
    // Legacy initializer for backward compatibility
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
         createdByDisplayName: String = "Unknown",
         createdByEmail: String = "unknown@example.com",
         calculatedTotals: [String: Double],
         roundingAdjustments: [String: Double] = [:],
         isDeleted: Bool = false) {
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
        self.createdByDisplayName = createdByDisplayName
        self.createdByEmail = createdByEmail
        self.lastModifiedBy = nil
        self.lastModifiedAt = nil
        self.calculatedTotals = calculatedTotals
        self.roundingAdjustments = roundingAdjustments
        self.isDeleted = isDeleted
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

struct BillItem: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var price: Double
    var participantIDs: [String] // Array of userIDs who split this item
    
    init(name: String, price: Double, participantIDs: [String]) {
        self.id = UUID().uuidString
        self.name = name
        self.price = price
        self.participantIDs = participantIDs
    }
}

struct BillParticipant: Codable, Identifiable, Equatable {
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