import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Error Types
enum BillCreationError: LocalizedError {
    case invalidUser
    case sessionNotReady
    case invalidData(String)
    case firestoreError(String)
    case participantNotFound
    case invalidAmount
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidUser:
            return "User authentication is invalid"
        case .sessionNotReady:
            return "Session is not ready for bill creation"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .firestoreError(let message):
            return "Database error: \(message)"
        case .participantNotFound:
            return "Required participant not found"
        case .invalidAmount:
            return "Bill amount is invalid"
        case .authenticationRequired:
            return "User must be logged in to create bills"
        }
    }
}

enum BillUpdateError: LocalizedError {
    case billNotFound
    case unauthorizedUpdate
    case invalidData(String)
    case concurrentModification
    case firestoreError(String)
    case versionMismatch(localVersion: Int, serverVersion: Int)
    case operationTimeout
    case conflictDetected(conflict: BillConflict)
    
    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill not found"
        case .unauthorizedUpdate:
            return "You don't have permission to update this bill"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .concurrentModification:
            return "Bill was modified by another user. Please refresh and try again."
        case .firestoreError(let message):
            return "Database error: \(message)"
        case .versionMismatch(let localVersion, let serverVersion):
            return "Version conflict: local version \(localVersion) vs server version \(serverVersion). Please refresh and try again."
        case .operationTimeout:
            return "Operation timed out. Please check your connection and try again."
        case .conflictDetected(let conflict):
            return "Conflict detected in fields: \(conflict.conflictingFields.joined(separator: ", ")). Manual resolution required."
        }
    }
}

enum BillDeleteError: LocalizedError {
    case billNotFound
    case unauthorizedDelete
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill not found"
        case .unauthorizedDelete:
            return "You don't have permission to delete this bill"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - Bill Service for Firebase Operations
final class BillService: ObservableObject {
    private let db = Firestore.firestore()
    private let pushNotificationService = PushNotificationService()
    
    /// Creates a new bill in Firestore with atomic transactions
    func createBill(from session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws -> Bill {
        guard let currentUser = authViewModel.currentUser else {
            throw BillCreationError.authenticationRequired
        }
        
        // Validate session data
        guard !session.items.isEmpty else {
            throw BillCreationError.invalidData("Bill must have at least one item")
        }
        
        guard session.totalAmount > 0 else {
            throw BillCreationError.invalidAmount
        }
        
        guard let paidByParticipant = session.participants.first(where: { $0.id == session.paidBy }) else {
            throw BillCreationError.participantNotFound
        }
        
        // Create bill with initial version
        let bill = Bill(
            createdBy: currentUser.uid,
            createdByDisplayName: currentUser.displayName ?? "Unknown",
            createdByEmail: currentUser.email ?? "unknown@example.com",
            paidBy: session.paidBy,
            paidByDisplayName: paidByParticipant.displayName,
            paidByEmail: paidByParticipant.email,
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
        
        try await saveBillToFirestore(bill: bill)
        
        // Send push notifications to other participants (Epic 2: US-SYNC-004)
        await pushNotificationService.notifyBillCreated(
            bill: bill,
            creatorName: currentUser.displayName ?? "Unknown",
            excludeUserId: currentUser.uid
        )
        
        return bill
    }
    
    /// Updates an existing bill with new data using optimistic locking
    func updateBill(billId: String, session: BillSplitSession, currentUserId: String, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws {
        guard let currentUser = authViewModel.currentUser else {
            throw BillUpdateError.unauthorizedUpdate
        }
        
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let billRef = self.db.collection("bills").document(billId)
            let billSnapshot: DocumentSnapshot
            
            do {
                billSnapshot = try transaction.getDocument(billRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "BillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch bill"])
                return nil
            }
            
            guard billSnapshot.exists else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bill not found"])
                return nil
            }
            
            guard let billData = try? billSnapshot.data(as: Bill.self) else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid bill data"])
                return nil
            }
            
            // Check authorization
            guard billData.createdBy == currentUserId else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unauthorized update"])
                return nil
            }
            
            // Check version for optimistic locking with detailed conflict detection
            if let expectedVersion = session.expectedVersion, billData.version != expectedVersion {
                // Create local bill representation from session
                let localBill = Bill(
                    id: billData.id,
                    createdBy: billData.createdBy,
                    createdByDisplayName: billData.createdByDisplayName,
                    createdByEmail: billData.createdByEmail,
                    paidBy: session.paidBy,
                    paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? billData.paidByDisplayName,
                    paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? billData.paidByEmail,
                    billName: session.billName,
                    totalAmount: session.totalAmount,
                    currency: session.currency,
                    date: billData.date,
                    createdAt: billData.createdAt,
                    items: session.items,
                    participants: session.participants,
                    calculatedTotals: session.calculatedTotals,
                    roundingAdjustments: session.roundingAdjustments,
                    isDeleted: billData.isDeleted,
                    version: expectedVersion,
                    operationId: UUID().uuidString
                )
                
                // Detect detailed conflicts
                let operationId = UUID().uuidString
                if let conflict = ConflictDetectionService.detectConflicts(
                    localBill: localBill,
                    serverBill: billData,
                    operationId: operationId
                ) {
                    // Try auto-resolution for compatible conflicts
                    if ConflictDetectionService.canAutoResolve(conflict: conflict),
                       let resolvedBill = ConflictDetectionService.autoResolveConflict(
                        localBill: localBill,
                        serverBill: billData,
                        conflict: conflict
                       ) {
                        // Use auto-resolved bill
                        try? transaction.setData(from: resolvedBill, forDocument: billRef)
                        return nil
                    }
                    
                    // Manual resolution required
                    errorPointer?.pointee = NSError(domain: "BillService", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Conflict detected: \(conflict.conflictingFields.joined(separator: ", "))",
                        "conflict": conflict
                    ])
                    return nil
                }
            }
            
            // Create updated bill
            let updatedBill = Bill(
                id: billData.id,
                createdBy: billData.createdBy,
                createdByDisplayName: billData.createdByDisplayName,
                createdByEmail: billData.createdByEmail,
                paidBy: session.paidBy,
                paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? billData.paidByDisplayName,
                paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? billData.paidByEmail,
                billName: session.billName,
                totalAmount: session.totalAmount,
                currency: session.currency,
                date: billData.date,
                createdAt: billData.createdAt,
                items: session.items,
                participants: session.participants,
                calculatedTotals: session.calculatedTotals,
                roundingAdjustments: session.roundingAdjustments,
                isDeleted: billData.isDeleted,
                version: billData.version + 1, // Increment version
                operationId: UUID().uuidString
            )
            
            // Update with incremented version
            try? transaction.setData(from: updatedBill, forDocument: billRef)
            return updatedBill // Return updated bill for notification
        })
        
        // Send push notifications to other participants after successful update (Epic 2: US-SYNC-005)
        if let currentUser = authViewModel.currentUser {
            // Create temporary bill object for notification
            let notificationBill = Bill(
                id: billId,
                createdBy: currentUserId,
                createdByDisplayName: currentUser.displayName ?? "Unknown",
                createdByEmail: currentUser.email ?? "unknown@example.com",
                paidBy: session.paidBy,
                paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? "Unknown",
                paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? "unknown@example.com",
                billName: session.billName,
                totalAmount: session.totalAmount,
                currency: session.currency,
                date: Date(),
                createdAt: Date(),
                items: session.items,
                participants: session.participants,
                calculatedTotals: session.calculatedTotals,
                roundingAdjustments: session.roundingAdjustments,
                isDeleted: false,
                version: 1,
                operationId: UUID().uuidString
            )
            
            await pushNotificationService.notifyBillEdited(
                bill: notificationBill,
                editorName: currentUser.displayName ?? "Unknown",
                excludeUserId: currentUserId
            )
        }
    }
    
    /// Deletes a bill from Firestore using soft deletion
    func deleteBill(billId: String, currentUserId: String) async throws {
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let billRef = self.db.collection("bills").document(billId)
            let billSnapshot: DocumentSnapshot
            
            do {
                billSnapshot = try transaction.getDocument(billRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "BillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch bill"])
                return nil
            }
            
            guard billSnapshot.exists else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bill not found"])
                return nil
            }
            
            guard let billData = try? billSnapshot.data(as: Bill.self) else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid bill data"])
                return nil
            }
            
            // Check authorization - only creator can delete
            guard billData.createdBy == currentUserId else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unauthorized delete"])
                return nil
            }
            
            // Soft delete by setting isDeleted flag and incrementing version
            var updatedBill = billData
            updatedBill.isDeleted = true
            updatedBill.version += 1
            updatedBill.operationId = UUID().uuidString
            
            try? transaction.setData(from: updatedBill, forDocument: billRef)
            return updatedBill // Return updated bill for notification
        })
        
        // Send push notifications to other participants after successful deletion (Epic 2: US-SYNC-006)
        // We need to get the updated bill data to send notifications
        do {
            let billSnapshot = try await db.collection("bills").document(billId).getDocument()
            if let deletedBill = try? billSnapshot.data(as: Bill.self),
               let currentUserDoc = try? await db.collection("users").document(currentUserId).getDocument(),
               let userData = currentUserDoc.data() {
                
                let deleterName = userData["displayName"] as? String ?? "Unknown"
                
                await pushNotificationService.notifyBillDeleted(
                    bill: deletedBill,
                    deleterName: deleterName,
                    excludeUserId: currentUserId
                )
            }
        } catch {
            print("⚠️ Failed to send deletion notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Saves bill to Firestore using atomic batch operations
    private func saveBillToFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Add bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update participant balances (for caching/aggregation)
        for participant in bill.participants {
            let participantRef = db.collection("participants").document(participant.id)
            batch.updateData([
                "lastActivity": Timestamp(),
                "isActive": true
            ], forDocument: participantRef)
        }
        
        // Commit batch atomically
        try await batch.commit()
    }
    
    /// Updates bill in Firestore using atomic operations
    private func updateBillInFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Update bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update participant activity timestamps
        for participant in bill.participants {
            let participantRef = db.collection("participants").document(participant.id)
            batch.updateData([
                "lastActivity": Timestamp(),
                "isActive": true
            ], forDocument: participantRef)
        }
        
        // Commit batch atomically
        try await batch.commit()
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for BillService extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */