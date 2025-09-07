import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - User Balance Model
struct UserBalance {
    var totalOwed: Double = 0.0     // Total amount user owes to others
    var totalOwedTo: Double = 0.0   // Total amount others owe to user
    var netBalance: Double {        // Positive = user is owed money, Negative = user owes money
        return totalOwedTo - totalOwed
    }
    
    // Individual breakdowns by person
    var balancesByPerson: [String: Double] = [:] // personId: netAmount (+ means they owe you, - means you owe them)
    
    // Get the top people user owes money to (for home screen display)
    var topDebts: [(personName: String, amount: Double)] {
        return balancesByPerson
            .filter { $0.value < 0 } // Only debts (negative values)
            .map { (personName: $0.key, amount: abs($0.value)) } // Convert to positive for display
            .sorted { $0.amount > $1.amount } // Sort by amount descending
            .prefix(3) // Top 3
            .map { $0 }
    }
    
    // Get the top people who owe user money (for home screen display)
    var topCredits: [(personName: String, amount: Double)] {
        return balancesByPerson
            .filter { $0.value > 0 } // Only credits (positive values)
            .map { (personName: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount } // Sort by amount descending
            .prefix(3) // Top 3
            .map { $0 }
    }
}

// MARK: - Bill Manager for Real-time Updates with Dual-State Architecture
final class BillManager: ObservableObject {
    private let db = Firestore.firestore()
    private let billService = BillService()
    
    // Dual-state architecture for Epic 1 real-time sync
    @Published var confirmedBills: [Bill] = []          // Server truth
    @Published var optimisticBills: [Bill] = []         // UI immediate state
    @Published var confirmedBalance: UserBalance = UserBalance()  // Server balance
    @Published var optimisticBalance: UserBalance = UserBalance() // UI balance
    @Published var pendingOperations: [BillOperation] = [] // In-flight operations
    @Published var activeConflicts: [BillConflict] = [] // Conflicts requiring user attention
    
    // Legacy single-state properties for backward compatibility
    @Published var userBills: [Bill] = []
    @Published var userBalance: UserBalance = UserBalance()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Epic 3: History Tab Real-Time Updates
    @Published var billActivities: [BillActivity] = []
    
    private var billsListener: ListenerRegistration?
    private var currentUserId: String?
    private var operationTimeouts: [String: Timer] = [:]
    
    init() {
        // Initialize with empty state
    }
    
    /// Sets up real-time bill monitoring for a specific user
    @MainActor
    func startMonitoring(userId: String) {
        currentUserId = userId
        loadUserBills()
        setupRealtimeListener()
        
        // Epic 3: Load bill activities for history tab
        Task {
            await loadBillActivities()
        }
    }
    
    // MARK: - Epic 1: Optimistic Update Operations
    
    /// Creates a bill with optimistic UI updates
    @MainActor
    func createBillOptimistically(from session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws -> Bill {
        guard let currentUserId = currentUserId else {
            throw BillCreationError.authenticationRequired
        }
        
        // Create optimistic bill
        let optimisticBill = Bill(
            createdBy: currentUserId,
            createdByDisplayName: authViewModel.currentUser?.displayName ?? "Unknown",
            createdByEmail: authViewModel.currentUser?.email ?? "unknown@example.com",
            paidBy: session.paidBy,
            paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? "Unknown",
            paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? "unknown@example.com",
            billName: session.billName,
            totalAmount: session.totalAmount,
            currency: session.currency,
            items: session.items,
            participants: session.participants,
            calculatedTotals: session.calculatedTotals,
            roundingAdjustments: session.roundingAdjustments,
            version: 1,
            operationId: UUID().uuidString
        )
        
        // Create operation tracking
        let operation = BillOperation(
            type: .create,
            billId: optimisticBill.id,
            optimisticState: optimisticBill,
            userId: currentUserId,
            timeoutSeconds: 10.0
        )
        
        // Apply optimistic update to UI immediately
        applyOptimisticCreate(bill: optimisticBill, operation: operation)
        
        // Start server operation in background
        Task {
            await confirmBillCreation(optimisticBill: optimisticBill, operation: operation, session: session, authViewModel: authViewModel, contactsManager: contactsManager)
        }
        
        return optimisticBill
    }
    
    /// Updates a bill with optimistic UI updates
    @MainActor
    func updateBillOptimistically(billId: String, with session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws {
        guard let currentUserId = currentUserId else {
            throw BillUpdateError.unauthorizedUpdate
        }
        
        guard let existingBill = confirmedBills.first(where: { $0.id == billId }) else {
            throw BillUpdateError.billNotFound
        }
        
        // Create optimistic updated bill
        let optimisticBill = Bill(
            id: existingBill.id,
            createdBy: existingBill.createdBy,
            createdByDisplayName: existingBill.createdByDisplayName,
            createdByEmail: existingBill.createdByEmail,
            paidBy: session.paidBy,
            paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? existingBill.paidByDisplayName,
            paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? existingBill.paidByEmail,
            billName: session.billName,
            totalAmount: session.totalAmount,
            currency: session.currency,
            date: existingBill.date,
            createdAt: existingBill.createdAt,
            items: session.items,
            participants: session.participants,
            calculatedTotals: session.calculatedTotals,
            roundingAdjustments: session.roundingAdjustments,
            isDeleted: existingBill.isDeleted,
            version: existingBill.version + 1,
            operationId: UUID().uuidString
        )
        
        // Create operation tracking
        let operation = BillOperation(
            type: .edit,
            billId: billId,
            optimisticState: optimisticBill,
            userId: currentUserId,
            timeoutSeconds: 10.0
        )
        
        // Apply optimistic update to UI immediately
        applyOptimisticUpdate(bill: optimisticBill, operation: operation)
        
        // Start server operation in background
        Task {
            await confirmBillUpdate(optimisticBill: optimisticBill, operation: operation, session: session, authViewModel: authViewModel, contactsManager: contactsManager)
        }
    }
    
    /// Deletes a bill with optimistic UI updates
    @MainActor
    func deleteBillOptimistically(billId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw BillDeleteError.unauthorizedDelete
        }
        
        guard let existingBill = confirmedBills.first(where: { $0.id == billId }) else {
            throw BillDeleteError.billNotFound
        }
        
        // Create operation tracking
        let operation = BillOperation(
            type: .delete,
            billId: billId,
            optimisticState: nil, // No optimistic state for delete
            userId: currentUserId,
            timeoutSeconds: 10.0
        )
        
        // Apply optimistic delete to UI immediately
        applyOptimisticDelete(billId: billId, operation: operation)
        
        // Start server operation in background
        Task {
            await confirmBillDeletion(billId: billId, operation: operation)
        }
    }
    
    /// Stops monitoring and cleans up listeners
    func stopMonitoring() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Force refresh bills and recalculate balances
    @MainActor
    func refreshBills() async {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Calculate user's balance across all bills
    private func calculateUserBalance() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Sets up real-time listener for bills where user is involved
    private func loadUserBills() {
        // TODO: Move implementation from original DataModels.swift
    }
    
    /// Sets up real-time Firestore listener
    private func setupRealtimeListener() {
        guard let userId = currentUserId else { return }
        
        billsListener = db.collection("bills")
            .whereField("participantIds", arrayContains: userId)
            .whereField("isDeleted", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let bills = documents.compactMap { document -> Bill? in
                        try? document.data(as: Bill.self)
                    }
                    
                    self.confirmedBills = bills
                    self.reconcileStates()
                }
            }
    }
    
    // MARK: - Optimistic Update Application
    
    /// Applies optimistic bill creation to UI
    @MainActor
    private func applyOptimisticCreate(bill: Bill, operation: BillOperation) {
        optimisticBills.append(bill)
        pendingOperations.append(operation)
        recalculateOptimisticBalance()
        updateLegacyState()
        setupOperationTimeout(for: operation)
    }
    
    /// Applies optimistic bill update to UI
    @MainActor
    private func applyOptimisticUpdate(bill: Bill, operation: BillOperation) {
        if let index = optimisticBills.firstIndex(where: { $0.id == bill.id }) {
            optimisticBills[index] = bill
        } else {
            // Bill might not be in optimistic state yet, add it
            optimisticBills.append(bill)
        }
        pendingOperations.append(operation)
        recalculateOptimisticBalance()
        updateLegacyState()
        setupOperationTimeout(for: operation)
    }
    
    /// Applies optimistic bill deletion to UI
    @MainActor
    private func applyOptimisticDelete(billId: String, operation: BillOperation) {
        optimisticBills.removeAll { $0.id == billId }
        pendingOperations.append(operation)
        recalculateOptimisticBalance()
        updateLegacyState()
        setupOperationTimeout(for: operation)
    }
    
    // MARK: - Server Confirmation Operations
    
    /// Confirms bill creation on server
    private func confirmBillCreation(optimisticBill: Bill, operation: BillOperation, session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async {
        do {
            let confirmedBill = try await billService.createBill(from: session, authViewModel: authViewModel, contactsManager: contactsManager)
            
            await MainActor.run {
                completeOperation(operationId: operation.id, success: true)
                
                // Epic 3: Record bill creation activity
                recordBillCreatedActivity(
                    bill: confirmedBill,
                    creatorName: authViewModel.currentUser?.displayName ?? "Unknown",
                    creatorEmail: authViewModel.currentUser?.email ?? ""
                )
            }
            
            // Save activity to Firestore for cross-user sync
            let activity = BillActivity(
                billId: confirmedBill.id,
                billName: confirmedBill.displayName,
                activityType: .created,
                actorName: authViewModel.currentUser?.displayName ?? "Unknown",
                actorEmail: authViewModel.currentUser?.email ?? "",
                participantEmails: confirmedBill.participants.map { $0.email },
                amount: confirmedBill.totalAmount,
                currency: confirmedBill.currency
            )
            await saveBillActivityToFirestore(activity)
            
        } catch {
            await MainActor.run {
                rollbackOperation(operationId: operation.id, error: error)
            }
        }
    }
    
    /// Confirms bill update on server
    private func confirmBillUpdate(optimisticBill: Bill, operation: BillOperation, session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async {
        do {
            try await billService.updateBill(billId: optimisticBill.id, session: session, currentUserId: operation.userId, authViewModel: authViewModel, contactsManager: contactsManager)
            
            await MainActor.run {
                completeOperation(operationId: operation.id, success: true)
                
                // Epic 3: Record bill edit activity
                recordBillEditedActivity(
                    bill: optimisticBill,
                    editorName: authViewModel.currentUser?.displayName ?? "Unknown",
                    editorEmail: authViewModel.currentUser?.email ?? ""
                )
            }
            
            // Save activity to Firestore for cross-user sync
            let activity = BillActivity(
                billId: optimisticBill.id,
                billName: optimisticBill.displayName,
                activityType: .edited,
                actorName: authViewModel.currentUser?.displayName ?? "Unknown",
                actorEmail: authViewModel.currentUser?.email ?? "",
                participantEmails: optimisticBill.participants.map { $0.email },
                amount: optimisticBill.totalAmount,
                currency: optimisticBill.currency
            )
            await saveBillActivityToFirestore(activity)
            
        } catch {
            await MainActor.run {
                rollbackOperation(operationId: operation.id, error: error)
            }
        }
    }
    
    /// Confirms bill deletion on server  
    private func confirmBillDeletion(billId: String, operation: BillOperation) async {
        // Get bill details before deletion for activity recording
        guard let billToDelete = optimisticBills.first(where: { $0.id == billId }) else {
            await MainActor.run {
                rollbackOperation(operationId: operation.id, error: BillDeleteError.billNotFound)
            }
            return
        }
        
        do {
            try await billService.deleteBill(billId: billId, currentUserId: operation.userId)
            
            await MainActor.run {
                completeOperation(operationId: operation.id, success: true)
                
                // Epic 3: Record bill deletion activity
                let deleterName = Auth.auth().currentUser?.displayName ?? "Unknown"
                let deleterEmail = Auth.auth().currentUser?.email ?? ""
                recordBillDeletedActivity(
                    bill: billToDelete,
                    deleterName: deleterName,
                    deleterEmail: deleterEmail
                )
            }
            
            // Save activity to Firestore for cross-user sync
            let activity = BillActivity(
                billId: billToDelete.id,
                billName: billToDelete.displayName,
                activityType: .deleted,
                actorName: Auth.auth().currentUser?.displayName ?? "Unknown",
                actorEmail: Auth.auth().currentUser?.email ?? "",
                participantEmails: billToDelete.participants.map { $0.email },
                amount: billToDelete.totalAmount,
                currency: billToDelete.currency
            )
            await saveBillActivityToFirestore(activity)
            
        } catch {
            await MainActor.run {
                rollbackOperation(operationId: operation.id, error: error)
            }
        }
    }
    
    // MARK: - State Reconciliation & Rollback Operations
    
    /// Reconciles optimistic and confirmed states
    @MainActor
    private func reconcileStates() {
        // Start with confirmed bills as base truth
        var reconciledBills = confirmedBills
        
        // Apply pending operations to create optimistic view
        for operation in pendingOperations {
            switch operation.state {
            case .optimistic, .confirming:
                if let optimisticState = operation.optimisticState {
                    switch operation.type {
                    case .create:
                        // Add optimistic bill if not already confirmed
                        if !reconciledBills.contains(where: { $0.id == optimisticState.id }) {
                            reconciledBills.append(optimisticState)
                        }
                    case .edit:
                        // Replace existing bill with optimistic version
                        if let index = reconciledBills.firstIndex(where: { $0.id == optimisticState.id }) {
                            reconciledBills[index] = optimisticState
                        }
                    case .delete:
                        // Remove bill optimistically
                        reconciledBills.removeAll { $0.id == operation.billId }
                    case .restore, .recalculate:
                        // Handle special operations
                        if let index = reconciledBills.firstIndex(where: { $0.id == optimisticState.id }) {
                            reconciledBills[index] = optimisticState
                        }
                    }
                } else if operation.type == .delete {
                    // Handle delete operation without optimistic state
                    reconciledBills.removeAll { $0.id == operation.billId }
                }
            case .confirmed, .failed, .rolledBack, .cancelled, .timedOut:
                // These operations are complete, no action needed
                break
            }
        }
        
        optimisticBills = reconciledBills
        recalculateOptimisticBalance()
        recalculateConfirmedBalance()
        updateLegacyState()
    }
    
    /// Completes a successful operation
    @MainActor
    private func completeOperation(operationId: String, success: Bool) {
        guard let index = pendingOperations.firstIndex(where: { $0.id == operationId }) else { return }
        
        var operation = pendingOperations[index]
        operation.state = success ? .confirmed : .failed(error: "Unknown error")
        pendingOperations[index] = operation
        
        // Cancel timeout timer
        operationTimeouts[operationId]?.invalidate()
        operationTimeouts.removeValue(forKey: operationId)
        
        // Remove completed operations after a delay for UI feedback
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                self.pendingOperations.removeAll { $0.id == operationId }
            }
        }
        
        reconcileStates()
    }
    
    /// Rolls back a failed operation
    @MainActor
    private func rollbackOperation(operationId: String, error: Error) {
        guard let index = pendingOperations.firstIndex(where: { $0.id == operationId }) else { return }
        
        var operation = pendingOperations[index]
        operation.state = .failed(error: error.localizedDescription)
        pendingOperations[index] = operation
        
        // Cancel timeout timer
        operationTimeouts[operationId]?.invalidate()
        operationTimeouts.removeValue(forKey: operationId)
        
        // Check if error contains conflict information
        if let nsError = error as NSError?,
           let conflict = nsError.userInfo["conflict"] as? BillConflict {
            handleConflict(conflict: conflict)
        } else {
            // Show general error to user
            errorMessage = "Operation failed: \(error.localizedDescription)"
        }
        
        // Reconcile states to remove optimistic changes
        reconcileStates()
        
        // Mark operation as rolled back after delay
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await MainActor.run {
                if let rollbackIndex = self.pendingOperations.firstIndex(where: { $0.id == operationId }) {
                    self.pendingOperations[rollbackIndex].state = .rolledBack
                }
            }
        }
    }
    
    // MARK: - Epic 1: Conflict Resolution System
    
    /// Handles detected conflicts
    @MainActor
    private func handleConflict(conflict: BillConflict) {
        // Add conflict to active list for UI handling
        activeConflicts.append(conflict)
        
        // Set user-friendly error message based on conflict severity
        switch conflict.severity {
        case .low:
            errorMessage = "Minor changes detected. Review and resolve conflict."
        case .medium:
            errorMessage = "Conflicting changes detected. Please review before continuing."
        case .high:
            errorMessage = "Significant conflicts found. Manual resolution required."
        case .critical:
            errorMessage = "Critical financial conflict detected. Operation blocked for safety."
        }
        
        // Auto-remove low severity conflicts after timeout
        if conflict.severity == .low {
            Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                await MainActor.run {
                    self.activeConflicts.removeAll { $0.id == conflict.id }
                }
            }
        }
    }
    
    /// Resolves a conflict using specified strategy
    @MainActor
    func resolveConflict(conflictId: String, resolution: ConflictResolution) async throws {
        guard let conflictIndex = activeConflicts.firstIndex(where: { $0.id == conflictId }),
              let operationIndex = pendingOperations.firstIndex(where: { $0.id == activeConflicts[conflictIndex].operationId }) else {
            throw BillUpdateError.invalidData("Conflict not found")
        }
        
        let conflict = activeConflicts[conflictIndex]
        let operation = pendingOperations[operationIndex]
        
        switch resolution {
        case .acceptLocal:
            // Retry operation with force flag
            try await retryOperationWithForce(operation: operation)
            
        case .acceptServer:
            // Cancel operation and refresh from server
            cancelOperation(operationId: operation.id)
            await refreshBills()
            
        case .merge:
            // Attempt automatic merge
            try await attemptAutoMerge(conflict: conflict, operation: operation)
            
        case .manual:
            // Keep conflict active for manual resolution UI
            return
            
        case .cancel:
            // Cancel operation entirely
            cancelOperation(operationId: operation.id)
        }
        
        // Remove resolved conflict
        activeConflicts.remove(at: conflictIndex)
    }
    
    /// Retries operation with force override
    private func retryOperationWithForce(operation: BillOperation) async throws {
        // Implementation would retry the operation with a force flag
        // This is a placeholder for the actual retry logic
        throw BillUpdateError.invalidData("Force retry not yet implemented")
    }
    
    /// Attempts automatic merge for compatible conflicts
    private func attemptAutoMerge(conflict: BillConflict, operation: BillOperation) async throws {
        // Implementation would attempt to merge changes automatically
        // This is a placeholder for the actual merge logic
        throw BillUpdateError.invalidData("Auto-merge not yet implemented")
    }
    
    /// Dismisses a conflict without resolution (for low severity only)
    @MainActor
    func dismissConflict(conflictId: String) {
        guard let index = activeConflicts.firstIndex(where: { $0.id == conflictId }) else { return }
        let conflict = activeConflicts[index]
        
        // Only allow dismissal for low severity conflicts
        guard conflict.severity == .low else { return }
        
        activeConflicts.remove(at: index)
    }
    
    /// Sets up timeout for operation
    @MainActor
    private func setupOperationTimeout(for operation: BillOperation) {
        let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleOperationTimeout(operationId: operation.id)
            }
        }
        operationTimeouts[operation.id] = timer
    }
    
    /// Handles operation timeout
    @MainActor
    private func handleOperationTimeout(operationId: String) {
        guard let index = pendingOperations.firstIndex(where: { $0.id == operationId }) else { return }
        
        var operation = pendingOperations[index]
        operation.state = .timedOut
        pendingOperations[index] = operation
        
        errorMessage = "Operation timed out. Please check your connection and try again."
        reconcileStates()
        
        // Clean up timer
        operationTimeouts.removeValue(forKey: operationId)
    }
    
    /// Cancels a pending operation
    @MainActor
    func cancelOperation(operationId: String) {
        guard let index = pendingOperations.firstIndex(where: { $0.id == operationId }) else { return }
        
        var operation = pendingOperations[index]
        operation.state = .cancelled
        pendingOperations[index] = operation
        
        // Cancel timeout timer
        operationTimeouts[operationId]?.invalidate()
        operationTimeouts.removeValue(forKey: operationId)
        
        reconcileStates()
    }
    
    // MARK: - Balance Calculations
    
    /// Recalculates optimistic balance from optimistic bills
    @MainActor
    private func recalculateOptimisticBalance() {
        guard let userId = currentUserId else { return }
        optimisticBalance = calculateBalance(from: optimisticBills, for: userId)
    }
    
    /// Recalculates confirmed balance from confirmed bills
    @MainActor
    private func recalculateConfirmedBalance() {
        guard let userId = currentUserId else { return }
        confirmedBalance = calculateBalance(from: confirmedBills, for: userId)
    }
    
    /// Calculates balance from a set of bills
    private func calculateBalance(from bills: [Bill], for userId: String) -> UserBalance {
        var balance = UserBalance()
        
        for bill in bills where !bill.isDeleted {
            // Calculate this user's share
            let userShare = bill.calculatedTotals[userId] ?? 0.0
            
            if bill.paidBy == userId {
                // User paid, others owe them
                balance.totalOwedTo += bill.totalAmount - userShare
            } else {
                // User owes to the payer
                balance.totalOwed += userShare
            }
            
            // Update per-person balances
            for (participantId, amount) in bill.calculatedTotals {
                guard participantId != userId else { continue }
                
                let participant = bill.participants.first { $0.id == participantId }
                let participantName = participant?.displayName ?? "Unknown"
                
                if bill.paidBy == userId {
                    // User paid, participant owes user
                    balance.balancesByPerson[participantName, default: 0.0] += amount
                } else if bill.paidBy == participantId {
                    // Participant paid, user owes participant
                    balance.balancesByPerson[participantName, default: 0.0] -= userShare
                }
            }
        }
        
        return balance
    }
    
    /// Updates legacy single-state properties for backward compatibility
    @MainActor
    private func updateLegacyState() {
        userBills = optimisticBills
        userBalance = optimisticBalance
    }
    
    // MARK: - Epic 3: Bill Activity Tracking
    
    /// Records a bill activity for history tracking
    @MainActor
    func recordBillActivity(billId: String, billName: String, activityType: BillActivity.ActivityType, actorName: String, actorEmail: String, participantEmails: [String], amount: Double, currency: String) {
        let activity = BillActivity(
            billId: billId,
            billName: billName,
            activityType: activityType,
            actorName: actorName,
            actorEmail: actorEmail,
            participantEmails: participantEmails,
            amount: amount,
            currency: currency
        )
        
        // Add to activities list (sorted by timestamp descending - newest first)
        billActivities.insert(activity, at: 0)
        
        // Limit to 100 most recent activities to prevent memory bloat
        if billActivities.count > 100 {
            billActivities = Array(billActivities.prefix(100))
        }
        
        print("📈 Epic 3: Recorded \\(activityType.displayName) activity for bill \\(billName) by \\(actorName)")
    }
    
    /// Records bill creation activity
    @MainActor
    func recordBillCreatedActivity(bill: Bill, creatorName: String, creatorEmail: String) {
        recordBillActivity(
            billId: bill.id,
            billName: bill.displayName,
            activityType: .created,
            actorName: creatorName,
            actorEmail: creatorEmail,
            participantEmails: bill.participants.map { $0.email },
            amount: bill.totalAmount,
            currency: bill.currency
        )
    }
    
    /// Records bill edit activity
    @MainActor
    func recordBillEditedActivity(bill: Bill, editorName: String, editorEmail: String) {
        recordBillActivity(
            billId: bill.id,
            billName: bill.displayName,
            activityType: .edited,
            actorName: editorName,
            actorEmail: editorEmail,
            participantEmails: bill.participants.map { $0.email },
            amount: bill.totalAmount,
            currency: bill.currency
        )
    }
    
    /// Records bill deletion activity
    @MainActor
    func recordBillDeletedActivity(bill: Bill, deleterName: String, deleterEmail: String) {
        recordBillActivity(
            billId: bill.id,
            billName: bill.displayName,
            activityType: .deleted,
            actorName: deleterName,
            actorEmail: deleterEmail,
            participantEmails: bill.participants.map { $0.email },
            amount: bill.totalAmount,
            currency: bill.currency
        )
    }
    
    /// Loads bill activities from Firestore for current user
    @MainActor
    private func loadBillActivities() async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            // Query activities where current user is in participants
            let activitiesQuery = db.collection("bill_activities")
                .whereField("participantEmails", arrayContains: await getCurrentUserEmail())
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
            
            let snapshot = try await activitiesQuery.getDocuments()
            var activities: [BillActivity] = []
            
            for document in snapshot.documents {
                if let activity = try? document.data(as: BillActivity.self) {
                    activities.append(activity)
                }
            }
            
            billActivities = activities
            print("📈 Epic 3: Loaded \\(activities.count) bill activities for user")
            
        } catch {
            print("❌ Epic 3: Failed to load bill activities: \\(error.localizedDescription)")
        }
    }
    
    /// Saves bill activity to Firestore for cross-user synchronization
    private func saveBillActivityToFirestore(_ activity: BillActivity) async {
        do {
            let activityRef = db.collection("bill_activities").document(activity.id)
            try await activityRef.setData(from: activity)
            print("✅ Epic 3: Saved activity \\(activity.activityType.displayName) to Firestore")
        } catch {
            print("❌ Epic 3: Failed to save activity to Firestore: \\(error.localizedDescription)")
        }
    }
    
    /// Gets current user email for activity queries
    private func getCurrentUserEmail() async -> String {
        return Auth.auth().currentUser?.email ?? ""
    }
    
    deinit {
        // Cancel all timers
        operationTimeouts.values.forEach { $0.invalidate() }
        stopMonitoring()
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for BillManager extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */