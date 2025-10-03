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
// NOTE: UIParticipant definition moved to Models/DataModels.swift (String-based ID for Firebase consistency)
// This file retains only legacy UI models not yet migrated

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

// NOTE: UIItem, UISummary, UISummaryParticipant, UIBreakdown definitions moved to Models/DataModels.swift
// (Updated to use String-based Firebase UIDs for consistency)
// This file retains only OCR-specific models not yet migrated