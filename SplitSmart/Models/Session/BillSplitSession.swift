import Foundation
import SwiftUI
import Combine

// MARK: - Bill Split Session State
enum SessionState {
    case notStarted
    case scanningReceipt
    case verifyingItems
    case assigningParticipants
    case reviewingSummary
    case savingBill
    case completed
    case cancelled
    case error(String)
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .scanningReceipt: return "Scanning Receipt"
        case .verifyingItems: return "Verifying Items"
        case .assigningParticipants: return "Assigning Participants"
        case .reviewingSummary: return "Reviewing Summary"
        case .savingBill: return "Saving Bill"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .error: return "Error"
        }
    }
}

// MARK: - Session Configuration
struct SessionConfiguration {
    let allowManualItemEntry: Bool
    let enableOCRProcessing: Bool
    let autoAssignItems: Bool
    let requireAllItemsAssigned: Bool
    let enableTaxCalculation: Bool
    let enableTipCalculation: Bool
    let currency: String
    let maxParticipants: Int
    
    static let `default` = SessionConfiguration(
        allowManualItemEntry: true,
        enableOCRProcessing: true,
        autoAssignItems: false,
        requireAllItemsAssigned: true,
        enableTaxCalculation: true,
        enableTipCalculation: true,
        currency: "USD",
        maxParticipants: 20
    )
}

// MARK: - Bill Split Session
final class BillSplitSession: ObservableObject, Identifiable {
    let id = UUID()
    
    // Session state
    @Published var state: SessionState = .notStarted
    @Published var configuration: SessionConfiguration
    
    // Bill data
    @Published var billName: String = ""
    @Published var scannedImage: UIImage?
    @Published var ocrResult: OCRResult?
    @Published var items: [UIItem] = []
    @Published var participants: [UIParticipant] = []
    @Published var selectedPayerId: Int?
    @Published var additionalCharges: AdditionalCharges = AdditionalCharges()
    
    // Validation state
    @Published var validationErrors: [ValidationError] = []
    @Published var isValid: Bool = false
    @Published var canProceedToNext: Bool = false
    
    // UI state
    @Published var isLoading: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String?
    @Published var currentScreenIndex: Int = 0
    
    // Session metadata
    let createdAt: Date
    var lastModifiedAt: Date
    private var cancellables = Set<AnyCancellable>()
    
    // Editing mode (for existing bill modifications)
    private(set) var isEditingMode: Bool = false
    private(set) var originalBill: Bill?
    
    init(configuration: SessionConfiguration = .default) {
        self.configuration = configuration
        self.createdAt = Date()
        self.lastModifiedAt = Date()
        setupValidationObservers()
    }
    
    /// Initializes session for editing an existing bill
    init(editingBill bill: Bill, configuration: SessionConfiguration = .default) {
        self.configuration = configuration
        self.createdAt = Date()
        self.lastModifiedAt = Date()
        self.isEditingMode = true
        self.originalBill = bill
        
        // Load bill data into session
        loadBillForEditing(bill)
        setupValidationObservers()
    }
    
    // MARK: - Session Lifecycle
    
    /// Starts a new bill split session
    func startSession() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Cancels the current session
    func cancelSession() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Completes the session and returns final bill data
    func completeSession() throws -> Bill {
        // TODO: Move implementation from original DataModels.swift
        fatalError("Implementation needs to be moved from DataModels.swift")
    }
    
    /// Resets session to initial state
    func resetSession() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    // MARK: - State Management
    
    /// Advances to next session state
    func advanceToNextState() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Goes back to previous session state
    func goToPreviousState() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Sets specific session state
    func setState(_ newState: SessionState) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Checks if session can advance to next state
    func canAdvanceToNextState() -> Bool {
        // TODO: Move implementation from original DataModels.swift
        return false
    }
    
    // MARK: - Item Management
    
    /// Adds item to session
    func addItem(_ item: UIItem) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Updates existing item
    func updateItem(at index: Int, with item: UIItem) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Removes item from session
    func removeItem(at index: Int) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Adds items from OCR results
    func addItemsFromOCR(_ ocrResult: OCRResult) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    // MARK: - Participant Management
    
    /// Adds participant to session
    func addParticipant(_ participant: UIParticipant) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Removes participant from session
    func removeParticipant(at index: Int) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Updates participant information
    func updateParticipant(at index: Int, with participant: UIParticipant) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Sets who paid for the bill
    func setPayerId(_ payerId: Int) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    // MARK: - Item Assignment
    
    /// Assigns item to specific participants
    func assignItem(itemId: Int, to participantIds: Set<Int>) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Removes participant assignment from item
    func removeAssignment(itemId: Int, from participantId: Int) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Auto-assigns items to all participants equally
    func autoAssignItemsEqually() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Gets unassigned items
    func getUnassignedItems() -> [UIItem] {
        // TODO: Move implementation from original DataModels.swift
        return []
    }
    
    // MARK: - Calculations
    
    /// Calculates total session amount
    func calculateTotalAmount() -> Double {
        // TODO: Move implementation from original DataModels.swift
        return 0.0
    }
    
    /// Calculates amount each participant owes
    func calculateParticipantTotals() -> [Int: Double] {
        // TODO: Move implementation from original DataModels.swift
        return [:]
    }
    
    /// Calculates summary for review screen
    func calculateSummary() -> UISummary {
        // TODO: Move implementation from original DataModels.swift
        return UISummary(
            restaurant: billName,
            date: DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .none),
            total: 0.0,
            paidBy: "",
            participants: [],
            breakdown: []
        )
    }
    
    // MARK: - Validation
    
    /// Sets up validation observers
    private func setupValidationObservers() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Validates current session state
    func validateSession() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Validates items are properly assigned
    private func validateItemAssignments() -> [ValidationError] {
        // TODO: Move implementation from original DataModels.swift
        return []
    }
    
    /// Validates participant information
    private func validateParticipants() -> [ValidationError] {
        // TODO: Move implementation from original DataModels.swift
        return []
    }
    
    /// Validates bill totals and calculations
    private func validateCalculations() -> [ValidationError] {
        // TODO: Move implementation from original DataModels.swift
        return []
    }
    
    // MARK: - Bill Editing Support
    
    /// Loads existing bill data for editing
    private func loadBillForEditing(_ bill: Bill) {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Checks if session has unsaved changes
    func hasUnsavedChanges() -> Bool {
        // TODO: Move implementation from original DataModels.swift
        return false
    }
    
    /// Gets changes made during editing
    func getEditingChanges() -> [String] {
        // TODO: Move implementation from original DataModels.swift
        return []
    }
    
    // MARK: - Session Persistence
    
    /// Saves session state for later restoration
    func saveSessionState() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Restores saved session state
    func restoreSessionState() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Clears saved session data
    func clearSavedState() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Additional Charges
struct AdditionalCharges {
    var tax: Double = 0.0
    var tip: Double = 0.0
    var deliveryFee: Double = 0.0
    var serviceFee: Double = 0.0
    var discount: Double = 0.0
    
    var totalAdditionalCharges: Double {
        return tax + tip + deliveryFee + serviceFee - discount
    }
}

// MARK: - Validation Error
struct ValidationError: Identifiable, Equatable {
    let id = UUID()
    let type: ValidationErrorType
    let message: String
    let field: String?
    let severity: Severity
    
    enum ValidationErrorType: String {
        case missingRequiredField
        case invalidAmount
        case unassignedItems
        case noParticipants
        case noPayerSelected
        case calculationError
        case duplicateParticipant
        case invalidParticipantData
    }
    
    enum Severity: String {
        case error, warning, info
    }
}

// MARK: - Session Statistics
struct SessionStatistics {
    let itemCount: Int
    let participantCount: Int
    let totalAmount: Double
    let averageAmountPerPerson: Double
    let sessionDuration: TimeInterval
    let stateTransitions: Int
    let validationErrors: Int
}

extension BillSplitSession {
    /// Gets session statistics for analytics
    func getSessionStatistics() -> SessionStatistics {
        return SessionStatistics(
            itemCount: items.count,
            participantCount: participants.count,
            totalAmount: calculateTotalAmount(),
            averageAmountPerPerson: participants.isEmpty ? 0 : calculateTotalAmount() / Double(participants.count),
            sessionDuration: Date().timeIntervalSince(createdAt),
            stateTransitions: 0, // TODO: Track this
            validationErrors: validationErrors.count
        )
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for BillSplitSession extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */