import Foundation
import FirebaseFirestore

// MARK: - Bill Settlement Data Models

struct Bill: Codable, Identifiable, Hashable {
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
    
    // Epic 1: Optimistic Updates & Version Control
    let version: Int                    // Optimistic locking version
    let operationId: String?           // Track operation lineage for conflict resolution
    
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
         isDeleted: Bool = false,
         version: Int = 1,
         operationId: String? = nil) {
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
        self.version = version
        self.operationId = operationId
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
         isDeleted: Bool = false,
         version: Int = 1,
         operationId: String? = nil) {
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
        self.version = version
        self.operationId = operationId
    }
    
    /// Returns the display name for the bill (custom name or default based on items)
    var displayName: String {
        if let billName = billName, !billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return billName
        } else {
            return items.count == 1 ? items[0].name : "\(items.count) items"
        }
    }

    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Bill, rhs: Bill) -> Bool {
        lhs.id == rhs.id
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

// MARK: - Epic 1: Optimistic Updates & Operation Tracking

/// Tracks bill operations for optimistic UI updates and conflict resolution
struct BillOperation: Identifiable, Codable {
    let id: String                      // Unique operation identifier
    let type: BillOperationType         // Type of operation
    let billId: String                  // Target bill ID
    let optimisticState: Bill?          // Optimistic state for UI
    let createdAt: Timestamp            // Operation start time
    let timeout: Timestamp              // Operation timeout threshold
    let userId: String                  // User who initiated operation
    var state: OperationState           // Current operation state
    let retryCount: Int                 // Number of retry attempts
    let parentOperationId: String?      // For operation chaining
    
    init(type: BillOperationType, 
         billId: String,
         optimisticState: Bill? = nil,
         userId: String,
         timeoutSeconds: TimeInterval = 10.0,
         parentOperationId: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.billId = billId
        self.optimisticState = optimisticState
        self.createdAt = Timestamp()
        self.timeout = Timestamp(date: Date().addingTimeInterval(timeoutSeconds))
        self.userId = userId
        self.state = .optimistic(timeout: Date().addingTimeInterval(timeoutSeconds))
        self.retryCount = 0
        self.parentOperationId = parentOperationId
    }
    
    /// Check if operation has timed out
    var hasTimedOut: Bool {
        return Date() > timeout.dateValue()
    }
    
    /// Get operation duration
    var duration: TimeInterval {
        return Date().timeIntervalSince(createdAt.dateValue())
    }
}

/// Types of bill operations for tracking
enum BillOperationType: String, Codable, CaseIterable {
    case create     = "create"
    case edit       = "edit" 
    case delete     = "delete"
    case restore    = "restore"    // Undo delete
    case recalculate = "recalculate" // Balance recalculation
    
    var displayName: String {
        switch self {
        case .create: return "Creating Bill"
        case .edit: return "Updating Bill"
        case .delete: return "Deleting Bill"
        case .restore: return "Restoring Bill"
        case .recalculate: return "Recalculating Balance"
        }
    }
    
    var verb: String {
        switch self {
        case .create: return "created"
        case .edit: return "updated"
        case .delete: return "deleted"
        case .restore: return "restored"
        case .recalculate: return "recalculated"
        }
    }
}

/// States of bill operations during optimistic updates
enum OperationState: Codable, Equatable {
    case optimistic(timeout: Date)      // Optimistic update applied, awaiting confirmation
    case confirming                     // Server operation in progress
    case confirmed                      // Server operation completed successfully  
    case failed(error: String)          // Server operation failed
    case rolledBack                     // Optimistic update rolled back due to failure
    case cancelled                      // Operation cancelled by user
    case timedOut                       // Operation exceeded timeout threshold
    
    var isComplete: Bool {
        switch self {
        case .confirmed, .rolledBack, .cancelled, .timedOut:
            return true
        case .optimistic, .confirming, .failed:
            return false
        }
    }
    
    var isSuccessful: Bool {
        switch self {
        case .confirmed:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .optimistic: return "Updating..."
        case .confirming: return "Confirming..."
        case .confirmed: return "Completed"
        case .failed: return "Failed"
        case .rolledBack: return "Cancelled"
        case .cancelled: return "Cancelled"
        case .timedOut: return "Timed Out"
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .failed, .timedOut:
            return true
        default:
            return false
        }
    }
}

/// Conflict detection and resolution for concurrent bill operations
struct BillConflict: Identifiable, Codable {
    let id: String
    let operationId: String             // Conflicting operation ID
    let localVersion: Int               // Client's bill version
    let serverVersion: Int              // Server's bill version
    let conflictingFields: [String]     // Fields that have conflicts
    let resolutionOptions: [ConflictResolution]
    let detectedAt: Timestamp
    let severity: ConflictSeverity
    
    init(operationId: String,
         localVersion: Int,
         serverVersion: Int,
         conflictingFields: [String],
         severity: ConflictSeverity = .medium) {
        self.id = UUID().uuidString
        self.operationId = operationId
        self.localVersion = localVersion
        self.serverVersion = serverVersion
        self.conflictingFields = conflictingFields
        self.resolutionOptions = ConflictResolution.availableResolutions(for: severity)
        self.detectedAt = Timestamp()
        self.severity = severity
    }
}

/// Conflict resolution strategies
enum ConflictResolution: String, Codable, CaseIterable {
    case acceptLocal    = "accept_local"     // Use client's version
    case acceptServer   = "accept_server"    // Use server's version
    case merge          = "merge"            // Attempt automatic merge
    case manual         = "manual"           // Require user resolution
    case cancel         = "cancel"           // Cancel operation
    
    var displayName: String {
        switch self {
        case .acceptLocal: return "Use My Changes"
        case .acceptServer: return "Use Server Version"
        case .merge: return "Merge Changes"
        case .manual: return "Resolve Manually"
        case .cancel: return "Cancel Operation"
        }
    }
    
    static func availableResolutions(for severity: ConflictSeverity) -> [ConflictResolution] {
        switch severity {
        case .low:
            return [.merge, .acceptLocal, .acceptServer, .cancel]
        case .medium:
            return [.manual, .acceptLocal, .acceptServer, .cancel]
        case .high:
            return [.manual, .cancel]
        case .critical:
            return [.cancel]
        }
    }
}

/// Severity levels for conflicts
enum ConflictSeverity: String, Codable, CaseIterable {
    case low        = "low"         // Minor field conflicts, auto-mergeable
    case medium     = "medium"      // Significant conflicts, requires attention
    case high       = "high"        // Major conflicts, potential data loss
    case critical   = "critical"    // Financial conflicts, must cancel
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "red"
        }
    }
}

/// Operation metrics for monitoring and debugging
struct OperationMetrics: Codable {
    let operationId: String
    let type: BillOperationType
    let startTime: Timestamp
    let endTime: Timestamp?
    let duration: TimeInterval?
    let success: Bool
    let errorMessage: String?
    let retryCount: Int
    let networkLatency: TimeInterval?
    let conflictsDetected: Int
    
    init(operation: BillOperation, success: Bool, errorMessage: String? = nil) {
        self.operationId = operation.id
        self.type = operation.type
        self.startTime = operation.createdAt
        self.endTime = Timestamp()
        self.duration = operation.duration
        self.success = success
        self.errorMessage = errorMessage
        self.retryCount = operation.retryCount
        self.networkLatency = nil  // Would be measured during actual operation
        self.conflictsDetected = 0  // Would be tracked during operation
    }
}