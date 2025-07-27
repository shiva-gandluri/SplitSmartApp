# SplitSmart User Stories & Implementation Plan

## Current Feature: Enhanced Summary Screen and Bill Settlement

### Implementation Phases

#### **Phase 1: Core Bill Creation & Summary Screen**
- [ ] Add "Who Paid" mandatory selection to Assign Items screen
- [ ] Redesign Summary Screen with "Who Owes Whom" section
- [ ] Implement minimalistic "Detailed Breakdown" with expandable cards
- [ ] Replace "Mark as Settled" with "Add Bill" button
- [ ] Create Bill data model with proper rounding logic ($10÷3 = $3.33, $3.33, $3.34)
- [ ] Implement Firestore Bill creation with atomic transactions
- [ ] Add loading states and error handling

#### **Phase 2: Real-time Updates & Home Screen Integration**
- [ ] Implement Firestore real-time listeners for bill updates
- [ ] Update home screen balances for all participants
- [ ] Add optimistic UI updates with rollback capability
- [ ] Handle chunked batch processing for large operations
- [ ] Implement proper offline/online state management

#### **Phase 3: Push Notifications & History Tab**
- [ ] Set up Firebase Cloud Messaging (FCM) for push notifications
- [ ] Send individual notifications to all participants when bill is added
- [ ] Update History tab with new bill entries
- [ ] Implement bill detail view from History tab
- [ ] Add notification content: "Who added the bill + bill name"

#### **Phase 4: Edit/Delete & Advanced Features**
- [ ] Add Edit/Delete options for bill creators in History tab
- [ ] Implement bill modification with revision tracking
- [ ] Add bill detail view for all participants (read-only for non-creators)
- [ ] Ghost participant prevention (block account deletion with unresolved expenses)
- [ ] Enhanced error recovery and retry mechanisms

### Financial Logic Rules

#### **Rounding Strategy**
- Round all amounts to 2 decimal places
- For splits that don't divide evenly, distribute remainder to ensure totals match
- Example: $10.00 ÷ 3 people = $3.33 + $3.33 + $3.34 = $10.00
- Always verify: sum(individual amounts) = total bill amount

#### **Currency Support**
- Current: USD only (matching existing regex patterns)
- Future: Multi-currency support with exchange rates

### Data Model Specifications

#### **Enhanced Bill Structure**
```swift
struct Bill: Codable {
    let id: String
    let paidBy: String // userID who paid
    let paidByDisplayName: String // Snapshot for UI
    let totalAmount: Double // Always matches sum of items
    let currency: String = "USD"
    let date: Timestamp
    let createdAt: Timestamp
    let items: [BillItem]
    let participants: [BillParticipant]
    let status: BillStatus = .pending
    
    // Audit trail
    let createdBy: String // userID who created bill
    let lastModifiedBy: String?
    let lastModifiedAt: Timestamp?
    
    // Financial reconciliation
    let calculatedTotals: [String: Double] // userID: amount owed
    let roundingAdjustments: [String: Double] // Track penny distributions
}
```

### Authorization & Permissions

#### **Bill Creation**
- Any participant can create bills
- "Who Paid" selection is mandatory
- Must select from existing participants

#### **Bill Management**
- **Creator permissions**: Edit, Delete, View
- **Participant permissions**: View only
- **Edit tracking**: Maintain revision history
- **Delete validation**: Confirm action with user

### Technical Requirements

#### **Performance & Reliability**
- **Consistency Model**: Strong consistency (not eventual)
- **Offline Support**: Must be online to add/check bills
- **Batch Processing**: Chunked operations with user notifications
- **Group Size Limit**: Maximum 15 participants
- **Notification Delivery**: Individual notifications using FCM

#### **Error Handling Standards**
- Atomic transactions with rollback capability
- Retry mechanisms with exponential backoff
- User-friendly error messages
- Transaction state recovery
- Network failure handling

## Pending Issues & Future Considerations

### **High Priority Issues to Review**

#### **1. Bill Edit/Delete Functionality**
- **Issue**: Bill details screen lacks edit and delete capabilities
- **Requirements**: Any bill participant can edit/delete bills with proper permissions
- **Edit Scope**: All bill fields (name, items, prices, participants, who paid)
- **Industry Standard**: Optimistic locking with version control for concurrent edits
- **Technical Approach**: 
  - Add `version` and `lastModifiedAt` fields to Bill model
  - Implement conflict detection before saves
  - Use "remove old + add new" strategy for balance recalculation
  - Add FCM notifications for edits/deletes
  - Include edit history tracking
- **Balance Recalculation**: Replace old bill contribution instead of adding to prevent cumulative errors
- **Confirmation**: Delete operations require confirmation dialog with balance impact warning

#### **2. Concurrent Edit Management**
- **Issue**: Multiple users editing same bill simultaneously
- **Industry Standard**: Optimistic locking with conflict resolution
- **Approach**: Check bill version before saving, show "Bill modified by someone else" error
- **Real-time Sync**: Consider Firestore listeners for live edit indicators
- **Fallback**: Force refresh and re-edit if conflicts detected

#### **3. Balance Recalculation Edge Cases**
- **Issue**: Edited bills should replace (not add to) existing balance contributions
- **Example**: Person A owes $1 → bill edited → Person A owes $2 (final balance should be $2, not $3)
- **Strategy**: Remove old bill's balance impact completely, then apply new bill's calculations
- **Validation**: Prevent edits that create invalid states (negative totals, no participants)
- **Integrity**: Show balance change preview before saving significant edits

#### **4. FCM Token Management**
- **Issue**: Firebase Cloud Messaging tokens expire and need refresh
- **Industry Standard**: Implement token refresh on app start and periodic validation
- **Approach**: Store tokens in Firestore user profile, refresh on token change events
- **Fallback**: Silent notification failure handling with retry logic

#### **5. Data Model Evolution & Migration**
- **Issue**: Existing TransactionContact vs new Bill participant data structures
- **Industry Standard**: Versioned data models with migration strategies
- **Approach**: Maintain backward compatibility, add version fields to documents
- **Migration**: Gradual migration of existing data to new structure

#### **6. Storage Cost Optimization**
- **Current**: No limits on transaction history storage
- **Future Consideration**: Implement data archiving for bills older than 2 years
- **Strategy**: Archive to cheaper storage tier, maintain searchable metadata
- **Priority**: Low (implement when storage costs become significant)

### **Medium Priority Enhancements**

#### **7. Multi-Currency Support**
- Add currency selection per bill
- Implement exchange rate API integration
- Handle currency conversion in split calculations

#### **8. Advanced Notification Options**
- User preferences for notification types
- Digest notifications (daily/weekly summaries)
- In-app notification center

#### **9. Bill Dispute Resolution**
- Comment system for bill items
- Request modification workflow
- Admin/mediator role for groups

### **Low Priority Future Features**

#### **10. Advanced Analytics**
- Spending patterns and insights
- Category-based expense tracking
- Monthly/yearly spending reports

#### **11. Integration Features**
- Receipt photo attachment
- Integration with banking/payment apps
- Export to accounting software

## Implementation Notes

### **Technology Stack Decisions**
- **Push Notifications**: Firebase Cloud Messaging (equivalent to AWS SNS)
- **Real-time Updates**: Firestore real-time listeners
- **State Management**: SwiftUI with @Published properties
- **Error Recovery**: Industry-standard retry with exponential backoff
- **Data Consistency**: Strong consistency with optimistic UI updates

### **Quality Assurance**
- Bulletproof reliability required
- Comprehensive error handling
- User experience priority over performance
- Financial accuracy is critical (penny-perfect calculations)

---

*Last Updated: [Current Date]*
*Status: In Development - Phase 1*