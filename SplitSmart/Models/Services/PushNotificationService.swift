import Foundation
import FirebaseFirestore
import Combine

// MARK: - Push Notification Service with Epic 2 Implementation

final class PushNotificationService: ObservableObject {
    private let db = Firestore.firestore()
    
    // Retry configuration for Epic 2 requirements
    private let maxRetryAttempts = 5
    private let baseRetryInterval: TimeInterval = 2.0 // 2s, 4s, 8s, 16s, 32s
    private let batchSize = 10 // Process 10 participants per batch for large groups
    private let batchDelay: TimeInterval = 3.0 // 3-second delay between batches
    
    // Retry queue for failed notifications
    @Published var pendingNotifications: [PendingNotification] = []
    @Published var notificationMetrics = NotificationMetrics()
    
    private var retryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupRetryQueue()
    }
    
    // MARK: - Epic 2: Bill Operation Notifications
    
    /// US-SYNC-004: New Bill Creation Notifications
    func notifyBillCreated(bill: Bill, creatorName: String, excludeUserId: String) async {
        let notification = BillNotification(
            type: .created,
            billId: bill.id,
            billName: bill.displayName,
            actorName: creatorName,
            message: "\(bill.displayName) - Added by \(creatorName)",
            deepLink: "splitsmart://bill/\(bill.id)"
        )
        
        // Get participant emails excluding the creator
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        // Update metrics
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.createdNotifications += 1
        }
    }
    
    /// US-SYNC-005: Bill Edit Notifications with Retry Queue
    func notifyBillEdited(bill: Bill, editorName: String, excludeUserId: String) async {
        let notification = BillNotification(
            type: .edited,
            billId: bill.id,
            billName: bill.displayName,
            actorName: editorName,
            message: "\(bill.displayName) - Edited by \(editorName)",
            deepLink: "splitsmart://bill/\(bill.id)"
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.editedNotifications += 1
        }
    }
    
    /// US-SYNC-006: Bill Deletion Notifications
    func notifyBillDeleted(bill: Bill, deleterName: String, excludeUserId: String) async {
        let notification = BillNotification(
            type: .deleted,
            billId: bill.id,
            billName: bill.displayName,
            actorName: deleterName,
            message: "\(bill.displayName) - Deleted by \(deleterName)",
            deepLink: "splitsmart://home" // Go to home screen for deleted bills
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.deletedNotifications += 1
        }
    }
    
    // MARK: - US-SYNC-007: Batch Processing for Large Groups
    
    private func sendNotificationToParticipants(notification: BillNotification, participantEmails: [String]) async {
        // For large groups (>10 participants), use batch processing
        if participantEmails.count > batchSize {
            await sendBatchedNotifications(notification: notification, participantEmails: participantEmails)
        } else {
            await sendSingleBatchNotification(notification: notification, participantEmails: participantEmails)
        }
    }
    
    /// US-SYNC-007: Batch notifications for large groups with rate limiting
    private func sendBatchedNotifications(notification: BillNotification, participantEmails: [String]) async {
        let batches = participantEmails.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            // Add delay between batches (except first batch)
            if index > 0 {
                try? await Task.sleep(nanoseconds: UInt64(batchDelay * 1_000_000_000))
            }
            
            await sendSingleBatchNotification(notification: notification, participantEmails: batch)
            
            await MainActor.run {
                notificationMetrics.batchesSent += 1
            }
        }
    }
    
    private func sendSingleBatchNotification(notification: BillNotification, participantEmails: [String]) async {
        do {
            // Get FCM tokens for participant emails
            let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
            
            // Send notifications to valid tokens
            for (email, token) in tokenMap {
                await sendNotificationWithRetry(
                    notification: notification,
                    token: token,
                    participantEmail: email
                )
            }
        } catch {
            print("❌ Error sending batch notification: \(error.localizedDescription)")
            
            await MainActor.run {
                notificationMetrics.totalFailed += participantEmails.count
            }
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    /// US-SYNC-005: Retry queue with exponential backoff (2s, 4s, 8s, 16s, 32s)
    private func sendNotificationWithRetry(notification: BillNotification, token: String, participantEmail: String) async {
        let pendingNotification = PendingNotification(
            id: UUID().uuidString,
            notification: notification,
            token: token,
            participantEmail: participantEmail,
            attemptCount: 0,
            nextRetryAt: Date(),
            createdAt: Date()
        )
        
        let success = await attemptNotificationDelivery(pendingNotification)
        
        if !success {
            await MainActor.run {
                self.pendingNotifications.append(pendingNotification)
            }
        }
    }
    
    private func attemptNotificationDelivery(_ pendingNotification: PendingNotification) async -> Bool {
        do {
            // Simulate FCM API call (would use Firebase Cloud Functions or FCM API)
            let success = await sendFCMNotification(
                token: pendingNotification.token,
                title: "SplitSmart",
                body: pendingNotification.notification.message,
                deepLink: pendingNotification.notification.deepLink,
                billId: pendingNotification.notification.billId
            )
            
            if success {
                await MainActor.run {
                    notificationMetrics.totalDelivered += 1
                }
                return true
            } else {
                throw NotificationError.deliveryFailed("FCM delivery failed")
            }
        } catch {
            print("❌ Notification delivery failed for \(pendingNotification.participantEmail): \(error.localizedDescription)")
            
            await MainActor.run {
                notificationMetrics.totalFailed += 1
            }
            return false
        }
    }
    
    /// Sets up retry queue processing
    private func setupRetryQueue() {
        // Process retry queue every 30 seconds
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.processRetryQueue()
            }
        }
    }
    
    /// Processes failed notifications with exponential backoff
    private func processRetryQueue() async {
        let now = Date()
        var notificationsToRetry: [PendingNotification] = []
        var notificationsToKeep: [PendingNotification] = []
        
        await MainActor.run {
            for notification in pendingNotifications {
                if notification.attemptCount >= maxRetryAttempts {
                    // Max retries reached, drop notification
                    notificationMetrics.totalDropped += 1
                } else if now >= notification.nextRetryAt {
                    // Ready for retry
                    notificationsToRetry.append(notification)
                } else {
                    // Still waiting for next retry
                    notificationsToKeep.append(notification)
                }
            }
            
            pendingNotifications = notificationsToKeep
        }
        
        // Retry failed notifications
        for var notification in notificationsToRetry {
            let success = await attemptNotificationDelivery(notification)
            
            if !success && notification.attemptCount < maxRetryAttempts {
                notification.attemptCount += 1
                // Exponential backoff: 2s, 4s, 8s, 16s, 32s
                let delaySeconds = baseRetryInterval * pow(2, Double(notification.attemptCount - 1))
                notification.nextRetryAt = Date().addingTimeInterval(delaySeconds)
                
                await MainActor.run {
                    self.pendingNotifications.append(notification)
                }
            }
        }
    }
    
    // MARK: - FCM Integration
    
    /// Simulates sending FCM notification (would integrate with Firebase Cloud Functions)
    private func sendFCMNotification(token: String, title: String, body: String, deepLink: String, billId: String) async -> Bool {
        // This would typically call Firebase Cloud Functions or FCM REST API
        // For now, we'll simulate the API call
        
        do {
            // Simulate network delay and potential failures
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000)) // 0.1-0.5s delay
            
            // Simulate 95% success rate (5% failure for retry testing)
            let success = Int.random(in: 1...100) <= 95
            
            if success {
                print("✅ FCM notification sent to token \(String(token.prefix(10)))... - \(body)")
                return true
            } else {
                print("❌ FCM notification failed for token \(String(token.prefix(10)))...")
                return false
            }
        } catch {
            return false
        }
    }
    
    /// US-SYNC-015: Deep linking support (will be used by UI)
    func handleNotificationTap(deepLink: String) {
        // This would be called by the app delegate or scene delegate
        // when user taps notification to navigate to specific bill
        print("🔗 Handling deep link: \(deepLink)")
    }
    
    // MARK: - Metrics and Monitoring
    
    func getNotificationMetrics() -> NotificationMetrics {
        return notificationMetrics
    }
    
    func resetMetrics() {
        notificationMetrics = NotificationMetrics()
    }
    
    deinit {
        retryTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Data Models

struct BillNotification: Codable, Identifiable {
    let id = UUID()
    let type: NotificationType
    let billId: String
    let billName: String
    let actorName: String
    let message: String
    let deepLink: String
    let timestamp = Date()
    
    enum NotificationType: String, Codable {
        case created = "created"
        case edited = "edited"
        case deleted = "deleted"
    }
}

struct PendingNotification: Identifiable {
    let id: String
    let notification: BillNotification
    let token: String
    let participantEmail: String
    var attemptCount: Int
    var nextRetryAt: Date
    let createdAt: Date
}

struct NotificationMetrics: Codable {
    var totalSent: Int = 0
    var totalDelivered: Int = 0
    var totalFailed: Int = 0
    var totalDropped: Int = 0
    var createdNotifications: Int = 0
    var editedNotifications: Int = 0
    var deletedNotifications: Int = 0
    var batchesSent: Int = 0
    
    var successRate: Double {
        return totalSent > 0 ? Double(totalDelivered) / Double(totalSent) : 0.0
    }
    
    var failureRate: Double {
        return totalSent > 0 ? Double(totalFailed) / Double(totalSent) : 0.0
    }
}

enum NotificationError: LocalizedError {
    case deliveryFailed(String)
    case tokenNotFound
    case rateLimited
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .deliveryFailed(let message):
            return "Notification delivery failed: \(message)"
        case .tokenNotFound:
            return "FCM token not found for participant"
        case .rateLimited:
            return "FCM rate limit exceeded"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}