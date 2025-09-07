import SwiftUI
import Foundation

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