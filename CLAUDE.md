# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SplitSmartApp is a native iOS app built with SwiftUI for splitting bills and tracking expenses. It uses Firebase for authentication and data persistence with Google Sign-In integration.

## Development Commands

### Build & Run
```bash
# Build the project
xcodebuild -project SplitSmart.xcodeproj -scheme SplitSmart -configuration Debug build

# Run in simulator (open Xcode and run)
open SplitSmart.xcodeproj
```

### Dependencies
Dependencies are managed via Swift Package Manager. The resolved packages are tracked in `SplitSmart.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Architecture

### Core Pattern
- **MVVM Architecture**: Clear separation with ViewModels managing state
- **SwiftUI**: Declarative UI with `@State`, `@StateObject`, `@EnvironmentObject`
- **Firebase Integration**: Authentication, Firestore, and error handling
- **Contacts Integration**: Native iOS ContactsUI framework for participant selection

### Key Components

#### Authentication (`AuthViewModel.swift`)
- Manages Google Sign-In flow and Firebase authentication
- Handles offline scenarios and API failures gracefully
- Uses async/await with timeout protection for Firestore operations
- **Important**: Firestore configuration happens in `SplitSmartApp.swift` app startup to avoid "settings already configured" errors

#### Navigation (`ContentView.swift`)
- Tab-based navigation with 5 main screens
- Conditional authentication flow (shows `AuthView` when not signed in)
- Environment object injection for shared state

#### UI Components (`UIComponents.swift`)
- Contains main screen implementations (Home, Scan, Profile)
- Mock data for development and testing
- Receipt scanning simulation flow
- Participant management with contacts integration

#### Contacts Management (in `UIComponents.swift`)
- ContactsPermissionManager: Handles contacts permissions and authorization
- ContactPicker: Wrapper for native contact selection UI
- CNContact extensions: Helper methods for contact data extraction
- Supports both manual entry and contact picker workflows

### Data Flow
1. App starts → Firebase configuration in `AppDelegate`
2. `AuthViewModel` checks authentication state
3. Shows `AuthView` or `ContentView` based on auth status
4. Main app uses tab navigation with shared `AuthViewModel`

## Firebase Setup

### Required Configuration
1. `GoogleService-Info.plist` must contain valid Firebase project credentials
2. Firestore API must be enabled in Firebase Console
3. Google Sign-In must be configured with proper OAuth client ID
4. Contacts permission must be configured in `Info.plist` with `NSContactsUsageDescription`

### Error Handling Patterns
- Firestore operations are non-blocking to prevent UI freezing
- Timeout protection (10 seconds) for network operations
- Graceful degradation when Firestore API is disabled
- Specific error codes handling (offline, permission denied, etc.)

## Development Considerations

### State Management
- `@Published` properties in ViewModels for reactive updates
- Environment objects for dependency injection
- Local `@State` for component-specific data

### Async Patterns
- Use `async/await` for Firebase operations
- Wrap Firestore operations in `Task` blocks for non-blocking execution
- Implement timeouts using `withThrowingTaskGroup`

### Firebase Integration
- **Critical**: Configure Firestore settings only once in app startup
- Use `source: .default` for offline-capable document reads
- Handle `FirestoreErrorCode.permissionDenied` for disabled APIs

### Security Implementation
- **Input Validation**: All user inputs are validated using `AuthViewModel.validateEmail()`, `validatePhoneNumber()`, and `validateDisplayName()`
- **Rate Limiting**: Database queries are throttled (30/minute, 1 second between requests)
- **Data Architecture**: Separate `users` (private) and `participants` (public lookup) collections
- **Auto-Migration**: Existing users are automatically migrated to participants collection on login
- **Firestore Rules**: Comprehensive validation functions for sessions, expenses, and groups
- **XSS Protection**: All inputs checked for malicious patterns like `<script`, `javascript:`, etc.
- **App Check**: Device authenticity verification with App Attest + DeviceCheck providers

### Migration & Backward Compatibility
- **Automatic Migration**: When existing users log in, they're automatically migrated to the new secure architecture
- **Dual Collection Lookup**: Validation checks both `users` and `participants` collections for backward compatibility
- **Zero Downtime**: Migration happens seamlessly without service interruption

## Common Issues & Solutions

### Authentication Flow
- If sign-in hangs: Check Firestore API is enabled and network connectivity
- If crashes on sign-out/sign-in: Ensure `isInitialized` flag is reset in `signOut()`
- If "settings already configured" error: Move Firestore config to app startup only

### Build Issues
- Use `withThrowingTaskGroup` for concurrent operations with error handling
- Ensure proper async/await syntax in TaskGroup operations

## File Structure Priority

When making changes:
1. **`AuthViewModel.swift`**: Authentication logic and state management
2. **`SplitSmartApp.swift`**: App configuration and Firebase setup
3. **`ContentView.swift`**: Main navigation and view hierarchy
4. **`UIComponents.swift`**: Screen implementations, UI logic, and contacts management
5. **`DataModels.swift`**: Core data models and OCR service

## Testing Notes

The app currently uses mock data for development. When implementing features:
- Replace mock data in `UIComponents.swift` with real Firebase queries
- Test both online and offline scenarios
- Verify authentication state persistence across app restarts

## 🧪 Critical Edge Case Test Suite

**Status**: POST-MVP TESTING - These test cases were identified during development and need comprehensive validation once the MVP ships.

**Priority**: CRITICAL - These tests ensure financial accuracy and data consistency, which are core requirements.

### **1. Payer Change Scenarios** 🔴 HIGH PRIORITY

**Test Case 1.1: Basic Payer Change**
- **Setup**: Bill $40, 2 people (User A, User B), originally paid by A
- **Action**: Edit bill, change payer to B
- **Expected**: A owes B $20, B owes nothing, net balance updates on both home screens
- **Previous Bug**: Fixed in session - was not recalculating `calculatedTotals`
- **Status**: ✅ FIXED - needs validation

**Test Case 1.2: Multi-participant Payer Change**
- **Setup**: Bill $60, 3 people (A, B, C), originally paid by A  
- **Action**: Change payer to B
- **Expected**: A owes B $20, C owes B $20, B owes nothing
- **Test**: Verify all participants see correct balances immediately

**Test Case 1.3: Payer Change with Unequal Splits**
- **Setup**: Bill $50, Item1 ($30 - A,B), Item2 ($20 - B,C), paid by A
- **Action**: Change payer to C
- **Expected**: A owes C $15, B owes C $35, C owes nothing
- **Critical**: Verify per-item calculations remain accurate

### **2. Item Assignment Edge Cases** 🟡 MEDIUM PRIORITY

**Test Case 2.1: Remove Participant from Item**
- **Setup**: Pizza $30 shared by (A, B, C) = $10 each, A paid
- **Action**: Remove C from pizza → now shared by (A, B) = $15 each  
- **Expected**: B owes A $15, C owes A $0
- **Test**: Verify debt recalculation and UI updates

**Test Case 2.2: Add Participant to Existing Item**
- **Setup**: Drink $20 assigned to B only, A paid
- **Action**: Add C to drink → now B and C each owe $10
- **Expected**: B owes A $10, C owes A $10
- **Test**: Check split calculation accuracy

**Test Case 2.3: Reassign All Items to Payer**
- **Setup**: Bill $50 with multiple items, A paid, assigned to B and C
- **Action**: Reassign all items to A only
- **Expected**: B owes A $0, C owes A $0, A effectively paid for own items
- **Test**: Verify zero-debt scenarios

### **3. Financial Precision Tests** 🔴 HIGH PRIORITY

**Test Case 3.1: Odd Cent Distribution**
- **Setup**: Bill $10.01 split equally among 3 people, A paid
- **Expected**: Smart distribution: [3.34, 3.34, 3.33] = exactly $10.01
- **Test**: No rounding errors, total preservation
- **Algorithm**: Uses penny distribution in `BillCalculator.calculateOwedAmounts()`

**Test Case 3.2: Complex Multi-Item Cents**
- **Setup**: Multiple items with odd prices (e.g., $7.77, $12.33, $5.49)
- **Action**: Various participant combinations per item  
- **Expected**: All calculations sum to exact bill total
- **Critical**: Verify `roundingAdjustments` field accuracy

**Test Case 3.3: Large Group Splitting**
- **Setup**: $100 bill, 7 participants, multiple items
- **Expected**: Precise cent distribution, no accumulating errors
- **Test**: Edge case for algorithm limits

### **4. Cross-Bill Balance Interactions** 🟡 MEDIUM PRIORITY

**Test Case 4.1: Net Balance Recalculation**
- **Setup**: 
  - Bill1: A owes B $15 
  - Bill2: B owes A $10
  - Net: A owes B $5
- **Action**: Edit Bill1, change payer from B to A  
- **Expected**: New net: A owes B $25
- **Test**: Home screen balance updates for both users

**Test Case 4.2: Multiple Bills with Same Participants**
- **Setup**: 5 bills between same 3 people with complex debt web
- **Action**: Edit one bill's payer or items
- **Expected**: All net balances recalculate correctly across all bills
- **Critical**: Verify BillManager's `calculateUserBalance()` accuracy

### **5. Real-Time Sync & Concurrency** 🟠 MEDIUM PRIORITY

**Test Case 5.1: Concurrent Edit Operations**
- **Setup**: Two users editing same bill simultaneously  
- **Expected**: Firebase handles conflicts, consistent final state
- **Test**: Race condition handling, no data corruption
- **Note**: Currently relies on Firebase transaction handling

**Test Case 5.2: Edit-Delete Race Condition**
- **Setup**: User A edits bill while User B deletes it
- **Expected**: Either edit succeeds then delete, or delete prevents edit
- **Test**: Atomic operation handling, proper error messages

**Test Case 5.3: Offline Edit Sync**
- **Setup**: User edits bill while offline, then comes online
- **Expected**: Changes sync correctly, no data loss
- **Status**: ⚠️ Offline handling not fully implemented

### **6. UI Consistency & State Management** 🟡 MEDIUM PRIORITY  

**Test Case 6.1: Home Screen Balance Updates**
- **Setup**: Any bill edit that changes user's balance
- **Expected**: Home screen reflects changes immediately (not on next app open)
- **Fixed**: Added explicit BillManager refresh after operations
- **Test**: Verify forced refresh in `deleteBill()` function works

**Test Case 6.2: History Screen Consistency**  
- **Setup**: Edit or delete bill
- **Expected**: History tab shows updated bill info immediately
- **Test**: Real-time listener effectiveness

**Test Case 6.3: Edit Flow Data Integrity**
- **Setup**: Navigate through full edit flow (Verify → Assign → Summary)
- **Expected**: All existing data pre-populated, no loading screens in edit mode
- **Fixed**: Added edit mode detection in UIAssignScreen
- **Test**: Verify `regexDetectedItems` pre-population works

### **7. Data Validation & Error Handling** 🟠 MEDIUM PRIORITY

**Test Case 7.1: Invalid Total Edits**
- **Setup**: Edit bill to create impossible totals (items > total amount)
- **Expected**: Validation prevents save, clear error message
- **Test**: `BillCalculator.validateBillTotals()` function

**Test Case 7.2: Participant Permission Edge Cases**
- **Setup**: Non-creator tries to edit/delete bill
- **Expected**: Operations blocked, appropriate error handling
- **Test**: Firebase security rules enforcement

**Test Case 7.3: Network Failure During Operations**  
- **Setup**: Edit/delete operation with network interruption
- **Expected**: Graceful failure, retry logic, user feedback
- **Test**: Error state handling, operation rollback

### **8. Delete Operation Edge Cases** 🔴 HIGH PRIORITY

**Test Case 8.1: Delete with Outstanding Balances**
- **Setup**: Bill where users owe money, then creator deletes
- **Expected**: All balances revert to pre-bill state immediately  
- **Fixed**: Added `isDeleted = false` filter to BillManager listener
- **Test**: Verify balance restoration accuracy

**Test Case 8.2: Delete Recently Edited Bill**
- **Setup**: Edit bill, then immediately delete it
- **Expected**: Only deletion affects final balances, edit changes ignored
- **Test**: Operation ordering consistency

## 🔧 Testing Implementation Notes

### Test Data Setup
```swift
// Example test bill creation
let testBill = Bill(
    paidBy: "user1",
    paidByDisplayName: "Alice", 
    paidByEmail: "alice@test.com",
    billName: "Test Dinner",
    totalAmount: 50.00,
    items: [
        BillItem(name: "Pizza", price: 30.00, participantIDs: ["user1", "user2"]),
        BillItem(name: "Drinks", price: 20.00, participantIDs: ["user1", "user2", "user3"])
    ],
    participants: [...],
    createdBy: "user1",
    calculatedTotals: [...] // Auto-calculated
)
```

### Automated Test Considerations
- **Unit Tests**: `BillCalculator.calculateOwedAmounts()` precision tests
- **Integration Tests**: Firebase operation consistency  
- **UI Tests**: Real-time updates and navigation flows
- **Load Tests**: Multiple users, concurrent operations
- **Precision Tests**: Cent distribution algorithms

### Manual Test Protocol
1. **Create Test Users**: At least 3 Firebase users
2. **Test Each Scenario**: Follow exact steps above
3. **Verify All Clients**: Check updates on all participant devices
4. **Financial Audit**: Manually verify all calculations
5. **Edge Case Exploration**: Try to break the system

**⚠️ CRITICAL**: All monetary calculations must be verified manually due to financial accuracy requirements.