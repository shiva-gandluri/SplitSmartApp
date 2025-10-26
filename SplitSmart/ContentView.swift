import SwiftUI
import FirebaseFirestore

// Ensure DataModels types are available
// Note: In same target, should be automatically available

struct ContentView: View {
    @State private var selectedTab = "home"
    @State private var isKeyboardVisible = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var sessionRecoveryManager: SessionRecoveryManager
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject private var billSplitSession = BillSplitSession()
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var billManager = BillManager()

    var showBackButton: Bool {
        return ["assign", "summary"].contains(selectedTab)
    }

    var body: some View {
        ZStack {
            mainContent
            sessionRecoveryOverlay
        }
        .lifecycleHandlers(
            authViewModel: authViewModel,
            contactsManager: contactsManager,
            billManager: billManager,
            billSplitSession: billSplitSession,
            setupKeyboardObservers: setupKeyboardObservers,
            removeKeyboardObservers: removeKeyboardObservers
        )
        .deepLinkHandlers(
            deepLinkCoordinator: deepLinkCoordinator,
            selectedTab: $selectedTab,
            billManager: billManager,
            authViewModel: authViewModel
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if showBackButton {
                backButtonSection
            }
            currentTabView
            if !isKeyboardVisible {
                TabBarView(selectedTab: $selectedTab)
            }
        }
        .background(Color.adaptiveDepth0.ignoresSafeArea())
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - View Components

    // MARK: - Refactored with Design System
    private var backButtonSection: some View {
        HStack {
            Button(action: handleBackAction) {
                HStack(spacing: .spacingXS) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Back")
                        .font(.bodyDynamic)
                }
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, .paddingScreen)
            .padding(.top, .spacingSM)
            Spacer()
        }
    }

    private var currentTabView: some View {
        Group {
            switch selectedTab {
            case "home":
                UIHomeScreen(session: billSplitSession, billManager: billManager, authViewModel: authViewModel, onCreateNew: startNewBill)
            case "scan":
                UIScanScreen(session: billSplitSession, onContinue: moveToAssign)
            case "assign":
                UIAssignScreen(session: billSplitSession, contactsManager: contactsManager, onContinue: moveToSummary)
            case "summary":
                UISummaryScreen(
                    session: billSplitSession,
                    onDone: handleSummaryComplete,
                    contactsManager: contactsManager,
                    authViewModel: authViewModel,
                    billManager: billManager
                )
            case "history":
                HistoryView(billManager: billManager, contactsManager: contactsManager)
                    .environmentObject(authViewModel)
            case "profile":
                UIProfileScreen()
                    .environmentObject(authViewModel)
                    .environmentObject(billManager)
            default:
                UIHomeScreen(session: billSplitSession, billManager: billManager, authViewModel: authViewModel, onCreateNew: startNewBill)
            }
        }
    }

    private var sessionRecoveryOverlay: some View {
        Group {
            if sessionRecoveryManager.showRecoveryBanner {
                VStack {
                    SessionRecoveryBanner(
                        onRestore: restoreSession,
                        onDiscard: { sessionRecoveryManager.discardRecovery() }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top))
                .animation(.easeInOut(duration: 0.3), value: sessionRecoveryManager.showRecoveryBanner)
            }
        }
    }

    // MARK: - Navigation Methods

    private func startNewBill() {
        billSplitSession.startNewSession()
        billSplitSession.currentScreenIndex = 1
        selectedTab = "scan"
    }

    private func moveToAssign() {
        billSplitSession.currentScreenIndex = 2
        selectedTab = "assign"
    }

    private func moveToSummary() {
        billSplitSession.completeAssignment()
        billSplitSession.currentScreenIndex = 3
        selectedTab = "summary"
    }

    private func handleSummaryComplete() {
        billSplitSession.completeSession()

        do {
            try SessionPersistenceManager.shared.clearSession()
        } catch {
            // Session cleared defensively
        }

        billSplitSession.currentScreenIndex = 0
        selectedTab = "home"
    }

    private func handleBackAction() {
        switch selectedTab {
        case "scan":
            selectedTab = "home"
        case "assign":
            // When going back from assign to scan, reset the session for fresh upload
            billSplitSession.resetSession()
            billSplitSession.sessionState = .scanning
            selectedTab = "scan"
        case "summary":
            selectedTab = "assign"
        default:
            selectedTab = "home"
        }
    }
    
    // MARK: - Session Recovery

    private func restoreSession() {

        guard let snapshot = sessionRecoveryManager.savedSessionSnapshot else {
            sessionRecoveryManager.discardRecovery()
            return
        }

        // Restore session data
        billSplitSession.restoreFrom(snapshot: snapshot)

        // Navigate to appropriate screen based on saved state
        let targetScreenIndex = snapshot.currentScreenIndex

        switch targetScreenIndex {
        case 0:
            // Home screen - should not happen, but handle gracefully
            selectedTab = "home"
        case 1:
            // Scan screen - unlikely but possible
            selectedTab = "scan"
        case 2:
            // Assign screen - most common recovery point
            selectedTab = "assign"
        case 3:
            // Summary screen
            selectedTab = "summary"
        default:
            // Default to assign screen for safety
            selectedTab = "assign"
        }


        // Accept recovery and hide banner
        sessionRecoveryManager.acceptRecovery()

        // Reset recovery manager after successful restoration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sessionRecoveryManager.reset()
        }
    }

    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Refactored TabBarView with Design System
struct TabBarView: View {
    @Binding var selectedTab: String

    var body: some View {
        HStack {
            TabButton(icon: "house.fill", label: "Home", isSelected: selectedTab == "home") {
                selectedTab = "home"
            }
            TabButton(icon: "camera.fill", label: "Scan", isSelected: selectedTab == "scan") {
                selectedTab = "scan"
            }
            TabButton(icon: "clock.fill", label: "History", isSelected: selectedTab == "history") {
                selectedTab = "history"
            }
            TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == "profile") {
                selectedTab = "profile"
            }
        }
        .padding(.horizontal, .paddingScreen)
        .padding(.top, .spacingSM)
        .padding(.bottom, .spacingXS)
        .background(Color.adaptiveDepth0)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
}

// TabButton is now in Components/TabButton.swift

struct UIHistoryScreen: View {
    @ObservedObject var billManager: BillManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("All your bills")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Bills List
                if billManager.isLoading {
                    Spacer()
                    ProgressView("Loading bills...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else if billManager.userBills.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No bills yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Bills you create or participate in will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(billManager.userBills) { bill in
                                NavigationLink(destination: SimpleBillDetailView(bill: bill, authViewModel: authViewModel, billManager: billManager)) {
                                    BillRowView(bill: bill, currentUserId: authViewModel.user?.uid ?? "")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                
                if let errorMessage = billManager.errorMessage {
                    VStack {
                        Text("Error loading bills")
                            .font(.headline)
                            .foregroundColor(.adaptiveAccentRed)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .onAppear {
                setupBillManager()
            }
            .onChange(of: authViewModel.user?.uid) { oldUserId, newUserId in
                if let userId = newUserId {
                    billManager.setCurrentUser(userId)
                } else {
                    billManager.clearCurrentUser()
                }
            }
        }
    }
    
    private func setupBillManager() {
        guard let userId = authViewModel.user?.uid else { return }
        billManager.setCurrentUser(userId)
    }
}

// MARK: - Bill History Components

struct BillHistoryCard: View {
    let bill: Bill
    
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header Row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(billDisplayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("Paid by \(bill.paidByDisplayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "$%.2f", bill.totalAmount))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(formatDate(bill.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Items Summary
                HStack {
                    Spacer()
                    
                    Text("\(bill.items.count) item\(bill.items.count == 1 ? "" : "s") • \(bill.participants.count) participant\(bill.participants.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(.cornerRadiusButton)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusButton)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
    }
    
    private var billDisplayName: String {
        return bill.displayName
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp.dateValue())
    }
}

// StatusBadge removed - bills no longer have status

// MARK: - Bill Detail View

struct BillDetailView: View {
    let bill: Bill
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(bill.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Bill • \(formatDate(bill.date))")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Bill Summary Card (matching Summary screen style)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let paidByParticipant = bill.participants.first(where: { $0.id == bill.paidBy }) {
                            Circle()
                                .fill(Color.adaptiveAccentBlue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                )
                            
                            Text("\(bill.paidByDisplayName) paid this bill")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Total amount:")
                        Spacer()
                        Text("$\(bill.totalAmount, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.adaptiveAccentBlue)
                    
                    HStack {
                        Text("Date & Time:")
                        Spacer()
                        Text("\(formatFullDate(bill.date))")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.adaptiveAccentBlue)
                }
                .padding()
                .background(Color.adaptiveAccentBlue.opacity(0.1))
                .cornerRadius(.cornerRadiusButton)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusButton)
                        .stroke(Color.adaptiveAccentBlue.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Who Owes Whom section (matching Summary screen style)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Who Owes Whom")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    // Show individual debts to the payer
                    ForEach(bill.calculatedTotals.sorted(by: { $0.key < $1.key }), id: \.key) { participantID, amountOwed in
                        if amountOwed > 0.01,
                           let debtor = bill.participants.first(where: { $0.id != bill.paidBy }) {
                            
                            HStack {
                                // From person (debtor)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.adaptiveAccentGreen)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        )
                                    
                                    Text(debtor.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                // Arrow
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                
                                Spacer()
                                
                                // To person (payer)
                                HStack(spacing: 8) {
                                    Text(bill.paidByDisplayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Circle()
                                        .fill(Color.adaptiveAccentBlue)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        )
                                }
                                
                                Spacer()
                                
                                // Amount owed
                                Text("$\(amountOwed, specifier: "%.2f")")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.adaptiveAccentGreen)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                    
                    if bill.calculatedTotals.isEmpty {
                        Text("No outstanding debts")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                
                // Detailed Breakdown section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detailed Breakdown")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ForEach(bill.items) { item in
                        ItemDetailCard(item: item, bill: bill, currentUserID: authViewModel.user?.uid ?? "")
                            .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 20)
            }
        }
        .navigationTitle("Bill Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp.dateValue())
    }
    
    private func formatFullDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp.dateValue())
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct ItemDetailCard: View {
    let item: BillItem
    let bill: Bill
    let currentUserID: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", item.price))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.adaptiveAccentBlue)
            }
            
            if !item.participantIDs.isEmpty {
                // Show participant avatars similar to Summary screen
                HStack(spacing: 8) {
                    Text("Split between:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(item.participantIDs, id: \.self) { participantID in
                        if let participant = getParticipantForID(participantID) {
                            Circle()
                                .fill(getColorForParticipant(participantID))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 8))
                                )
                        }
                    }
                    
                    Spacer()
                }
                
                // Show names
                let participantNames = item.participantIDs.compactMap { participantID in
                    getParticipantForID(participantID)
                }
                
                Text(participantNames.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func getParticipantForID(_ participantID: String) -> String? {
        if participantID == currentUserID {
            return "You"
        } else {
            return bill.participants.first { $0.id == participantID }?.displayName
        }
    }
    
    private func getColorForParticipant(_ participantID: String) -> Color {
        if participantID == currentUserID {
            return .blue
        } else {
            return .green
        }
    }
}

// ParticipantDebtCard removed - replaced with integrated "Who Owes Whom" design

// MARK: - UIHomeScreen with Recent Bills (Refactored with Design System)

struct UIHomeScreen: View {
    let session: BillSplitSession
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    let onCreateNew: () -> Void

    // Real-time balance data from BillManager (using net balances)
    private var totalOwed: Double {
        billManager.getPeopleWhoOweUser().reduce(0) { $0 + $1.total }
    }
    private var totalOwe: Double {
        billManager.getPeopleUserOwes().reduce(0) { $0 + $1.total }
    }

    // Detailed debt breakdown for individual people from BillManager
    private var peopleWhoOweMe: [UIPersonDebt] {
        billManager.getPeopleWhoOweUser()
    }
    private var peopleIOwe: [UIPersonDebt] {
        billManager.getPeopleUserOwes()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: .spacingLG) {
                    // Header with design system typography
                    HStack {
                        Text("SplitSmart")
                            .font(.h2Dynamic)
                            .foregroundColor(.adaptiveTextPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, .paddingScreen)
                    
                    // Loading indicator with design system
                    if billManager.isLoading {
                        HStack(spacing: .spacingSM) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading balances...")
                                .font(.smallDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                        .padding(.spacingMD)
                    }

                    // Balance Cards with design system colors and spacing
                    HStack(spacing: .spacingSM) {
                        // "You are owed" card - muted green for softer appearance
                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("You are owed")
                                .font(.captionDynamic)
                                .foregroundColor(.adaptiveMutedGreen)

                            Text("$\(totalOwed, specifier: "%.2f")")
                                .font(.h3Dynamic)
                                .foregroundColor(.adaptiveMutedGreen)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.spacingSM)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                Color.adaptiveDepth1
                                Color.adaptiveMutedGreen.opacity(0.1)
                            }
                        )
                        .cornerRadius(.cornerRadiusSmall)
                        .shadow(color: Color.black.opacity(0.10), radius: 2, x: 2, y: 2)

                        // "You owe" card - muted red for softer appearance
                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("You owe")
                                .font(.captionDynamic)
                                .foregroundColor(.adaptiveMutedRed)

                            Text("$\(totalOwe, specifier: "%.2f")")
                                .font(.h3Dynamic)
                                .foregroundColor(.adaptiveMutedRed)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.spacingSM)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                Color.adaptiveDepth1
                                Color.adaptiveMutedRed.opacity(0.1)
                            }
                        )
                        .cornerRadius(.cornerRadiusSmall)
                        .shadow(color: Color.black.opacity(0.10), radius: 2, x: 2, y: 2)
                    }
                    .padding(.horizontal, .paddingScreen)

                    // People who owe you - refactored with design system
                    if !peopleWhoOweMe.isEmpty {
                        VStack(alignment: .leading, spacing: .spacingSM) {
                            HStack(spacing: .spacingXS) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 18))
                                    .foregroundColor(.adaptiveAccentGreen)
                                Text("People who owe you")
                                    .font(.smallDynamic)
                                    .foregroundColor(.adaptiveTextPrimary)
                            }
                            .padding(.horizontal, .paddingScreen)

                            VStack(spacing: .spacingXS) {
                                ForEach(peopleWhoOweMe) { person in
                                    HStack(spacing: .spacingMD) {
                                        Circle()
                                            .fill(person.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            )

                                        Text(person.name)
                                            .font(.bodyDynamic)
                                            .foregroundColor(.adaptiveTextPrimary)

                                        Spacer()

                                        Text("$\(person.total, specifier: "%.2f")")
                                            .font(.bodyDynamic)
                                            .fontWeight(.bold)
                                            .foregroundColor(.adaptiveAccentGreen)
                                    }
                                    .padding(.vertical, .spacingXS)
                                    .padding(.horizontal, .paddingScreen)
                                }
                            }
                        }
                    }
                    
                    // People you owe - refactored with design system
                    if !peopleIOwe.isEmpty {
                        VStack(alignment: .leading, spacing: .spacingSM) {
                            HStack(spacing: .spacingXS) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(.adaptiveAccentRed)
                                Text("People you owe")
                                    .font(.smallDynamic)
                                    .foregroundColor(.adaptiveTextPrimary)
                            }
                            .padding(.horizontal, .paddingScreen)

                            VStack(spacing: .spacingXS) {
                                ForEach(peopleIOwe) { person in
                                    HStack(spacing: .spacingMD) {
                                        Circle()
                                            .fill(person.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            )

                                        Text(person.name)
                                            .font(.bodyDynamic)
                                            .foregroundColor(.adaptiveTextPrimary)

                                        Spacer()

                                        Text("$\(person.total, specifier: "%.2f")")
                                            .font(.bodyDynamic)
                                            .fontWeight(.bold)
                                            .foregroundColor(.adaptiveAccentRed)
                                    }
                                    .padding(.vertical, .spacingXS)
                                    .padding(.horizontal, .paddingScreen)
                                }
                            }
                        }
                    }

                    // All settled up message - refactored with design system
                    if peopleWhoOweMe.isEmpty && peopleIOwe.isEmpty {
                        VStack(spacing: .spacingXS) {
                            Text("All settled up!")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Text("You have no outstanding balances")
                                .font(.captionDynamic)
                                .foregroundColor(.adaptiveTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.spacingMD)
                        .background(Color.adaptiveDepth1)
                        .cornerRadius(.cornerRadiusSmall)
                        .padding(.horizontal, .paddingScreen)
                    }
                }
                .padding(.top, .spacingMD)
                .padding(.bottom, 80)
            }
            .background(Color.adaptiveDepth0)
            .overlay(
                // Floating Action Button (FAB) - Modern UI pattern
                VStack {
                    Spacer()
                    Button(action: onCreateNew) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color.adaptiveAccentBlue)
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.bottom, 20)
                }
                , alignment: .bottom
            )
        }
    }
}

// MARK: - Supporting Views

// Simplified Bill Detail View for demonstration
struct SimpleBillDetailView: View {
    let bill: Bill
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var billManager: BillManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentBill: Bill?

    private var displayBill: Bill {
        currentBill ?? bill
    }

    private var isCreator: Bool {
        authViewModel.user?.uid == displayBill.createdBy
    }

    var body: some View {

        ScrollView {
            VStack(spacing: 20) {
                // Debug tracking and refetch bill
                Color.clear.frame(height: 0).onAppear {
                    Task {
                        if let freshBill = await billManager.getBillById(bill.id) {
                            await MainActor.run {
                                currentBill = freshBill
                            }
                        }
                    }
                }

                // Header
                VStack(spacing: 8) {
                    Text(displayBill.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("$\(displayBill.totalAmount, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.adaptiveAccentBlue)

                    Text("Created on \(displayBill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items (\(displayBill.items.count))")
                        .font(.headline)
                        .fontWeight(.semibold)

                    ForEach(displayBill.items) { item in
                        HStack {
                            Text(item.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("$\(item.price, specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(.cornerRadiusButton)

                // Action buttons for creators
                if isCreator && !displayBill.isDeleted {
                    BillActionButtons(bill: displayBill, authViewModel: authViewModel, billManager: billManager)
                }

                if displayBill.isDeleted {
                    Text("This bill has been deleted")
                        .font(.headline)
                        .foregroundColor(.adaptiveAccentRed)
                        .padding()
                        .background(Color.adaptiveAccentRed.opacity(0.1))
                        .cornerRadius(.cornerRadiusButton)
                }
            }
            .padding()
        }
        .navigationTitle("Bill Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BillActionButtons: View {
    let bill: Bill
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var billManager: BillManager
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button("Edit Bill") {
                showingEditSheet = true
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Delete Bill") {
                showingDeleteAlert = true
            }
            .buttonStyle(DestructiveButtonStyle())
        }
        .padding()
        .sheet(isPresented: $showingEditSheet) {
            BillEditFlow(bill: bill, authViewModel: authViewModel, billManager: billManager, contactsManager: ContactsManager())
        }
        .alert("Delete Bill", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteBill()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(bill.displayName)'? This action cannot be undone.")
        }
    }
    
    @MainActor
    private func deleteBill() async {
        do {
            let billService = BillService()
            try await billService.deleteBill(
                billId: bill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )
            
            // Force refresh the bill manager to ensure balance updates immediately
            if let userId = authViewModel.user?.uid {
                billManager.setCurrentUser(userId)
            }
        } catch {
            // TODO: Show error alert to user
        }
    }
}

// MARK: - Bill Edit Flow
// BillEditFlow extracted to Views/BillEdit/BillEditFlow.swift

// MARK: - Bill Edit Confirmation View
// BillEditConfirmationView extracted to Views/BillEdit/BillEditConfirmation.swift

// MARK: - Bill Edit Summary Screen
// BillEditSummaryScreen extracted to Views/BillEdit/BillEditSummary.swift

// MARK: - Simple Item Edit Row

struct SimpleItemEditRow: View {
    @Binding var item: BillItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Item name", text: $item.name)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", value: $item.price, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }
            
            HStack {
                Text("Split among \(item.participantIDs.count) people")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .font(.caption)
                .foregroundColor(.adaptiveAccentRed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct BillRowView: View {
    let bill: Bill
    let currentUserId: String
    
    private var isCreator: Bool {
        bill.createdBy == currentUserId
    }
    
    private var owedAmount: Double {
        let owedAmounts = BillCalculator.calculateOwedAmounts(bill: bill)
        return owedAmounts[currentUserId] ?? 0.0
    }
    
    private var isOwedMoney: Bool {
        bill.paidBy == currentUserId
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .strikethrough(bill.isDeleted)
                
                Text(bill.date.dateValue().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if bill.isDeleted {
                    Text("Deleted")
                        .font(.caption)
                        .foregroundColor(.adaptiveAccentRed)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(bill.totalAmount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if !bill.isDeleted {
                    if isOwedMoney {
                        Text("You paid")
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentGreen)
                    } else if owedAmount > 0.01 {
                        Text("You owe $\(owedAmount, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentRed)
                    } else {
                        Text("Settled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isCreator {
                    HStack(spacing: 2) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.caption2)
                    .foregroundColor(.adaptiveAccentBlue)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - View Modifiers

/// ViewModifier for lifecycle event handling
private struct LifecycleModifiers: ViewModifier {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var billManager: BillManager
    @ObservedObject var billSplitSession: BillSplitSession
    @Environment(\.scenePhase) var scenePhase

    let setupKeyboardObservers: () -> Void
    let removeKeyboardObservers: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                setupKeyboardObservers()

                if let userId = authViewModel.user?.uid {
                    contactsManager.setCurrentUser(userId)
                    billManager.setCurrentUser(userId)
                }
            }
            .onChange(of: authViewModel.user?.uid) { oldUserId, newUserId in
                if let userId = newUserId {
                    contactsManager.setCurrentUser(userId)
                    billManager.setCurrentUser(userId)
                } else {
                    contactsManager.clearCurrentUser()
                    billManager.clearCurrentUser()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    billSplitSession.autoSaveSession()
                }
            }
            .onDisappear {
                removeKeyboardObservers()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                billSplitSession.autoSaveSession()
            }
    }
}

/// ViewModifier for deep link handling
private struct DeepLinkHandlingModifiers: ViewModifier {
    @ObservedObject var deepLinkCoordinator: DeepLinkCoordinator
    @Binding var selectedTab: String
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: deepLinkCoordinator.activeDestination) { oldDestination, newDestination in
                if case .billDetail = newDestination {
                    // Navigation handled by sheet below
                } else if case .home = newDestination {
                    selectedTab = "home"
                    deepLinkCoordinator.clearDestination()
                }
            }
            .sheet(item: $deepLinkCoordinator.activeDestination) { destination in
                if case .billDetail(let bill) = destination {
                    NavigationView {
                        VStack(spacing: 20) {
                            Text("Bill Detail")
                                .font(.title)
                                .bold()

                            Text(bill.billName ?? "Unnamed Bill")
                                .font(.headline)

                            Text("Total: $\(bill.totalAmount, specifier: "%.2f")")
                                .font(.title2)

                            Spacer()

                            Button("Close") {
                                deepLinkCoordinator.clearDestination()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    deepLinkCoordinator.clearDestination()
                                }
                            }
                        }
                    }
                }
            }
            .alert("Deep Link Error", isPresented: .constant(deepLinkCoordinator.errorMessage != nil)) {
                Button("OK") {
                    deepLinkCoordinator.clearDestination()
                }
            } message: {
                Text(deepLinkCoordinator.errorMessage ?? "")
            }
    }
}

extension View {
    func lifecycleHandlers(
        authViewModel: AuthViewModel,
        contactsManager: ContactsManager,
        billManager: BillManager,
        billSplitSession: BillSplitSession,
        setupKeyboardObservers: @escaping () -> Void,
        removeKeyboardObservers: @escaping () -> Void
    ) -> some View {
        modifier(LifecycleModifiers(
            authViewModel: authViewModel,
            contactsManager: contactsManager,
            billManager: billManager,
            billSplitSession: billSplitSession,
            setupKeyboardObservers: setupKeyboardObservers,
            removeKeyboardObservers: removeKeyboardObservers
        ))
    }

    func deepLinkHandlers(
        deepLinkCoordinator: DeepLinkCoordinator,
        selectedTab: Binding<String>,
        billManager: BillManager,
        authViewModel: AuthViewModel
    ) -> some View {
        modifier(DeepLinkHandlingModifiers(
            deepLinkCoordinator: deepLinkCoordinator,
            selectedTab: selectedTab,
            billManager: billManager,
            authViewModel: authViewModel
        ))
    }
}

// MARK: - Session Recovery Banner Component

/// Banner UI component for session recovery prompt
struct SessionRecoveryBanner: View {
    let onRestore: () -> Void
    let onDiscard: () -> Void
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Card-based banner with modern iOS design
            VStack(spacing: 16) {
                // Icon and Header
                HStack(spacing: 12) {
                    // Circular icon background with gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.adaptiveAccentBlue.opacity(0.2), Color.adaptiveAccentBlue.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.adaptiveAccentBlue, .adaptiveAccentBlue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unfinished Bill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Resume your previous session")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Action buttons with modern design
                HStack(spacing: 12) {
                    // Discard button - secondary style
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onDiscard()
                        }
                    } label: {
                        Text("Start Fresh")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(.cornerRadiusButton)
                    }

                    // Restore button - primary style
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onRestore()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                            Text("Continue")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.adaptiveAccentBlue, Color.adaptiveAccentBlue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(.cornerRadiusButton)
                        .shadow(color: Color.adaptiveAccentBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 60) // Below status bar
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }

            Spacer()
        }
        .background(
            Color.black.opacity(0.25)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Dismiss on backdrop tap
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDiscard()
                    }
                }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}

// MARK: - Canvas Preview Configurations

#Preview("Complete App - Light") {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(SessionRecoveryManager())
        .environmentObject(DeepLinkCoordinator())
        .preferredColorScheme(.light)
}

#Preview("Complete App - Dark") {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(SessionRecoveryManager())
        .environmentObject(DeepLinkCoordinator())
        .preferredColorScheme(.dark)
}

#Preview("Home Screen Only - Light") {
    NavigationView {
        UIHomeScreen(
            session: BillSplitSession(),
            billManager: BillManager(),
            authViewModel: AuthViewModel(),
            onCreateNew: {}
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Home Screen Only - Dark") {
    NavigationView {
        UIHomeScreen(
            session: BillSplitSession(),
            billManager: BillManager(),
            authViewModel: AuthViewModel(),
            onCreateNew: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Balance Cards - Light") {
    VStack(spacing: .spacingLG) {
        HStack(spacing: .spacingSM) {
            // "You are owed" card
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("You are owed")
                    .font(.captionDynamic)
                    .foregroundColor(.adaptiveMutedGreen)

                Text("$156.50")
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveMutedGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingSM)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Color.adaptiveDepth1
                    Color.adaptiveMutedGreen.opacity(0.1)
                }
            )
            .cornerRadius(.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 2, y: 4)

            // "You owe" card
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("You owe")
                    .font(.captionDynamic)
                    .foregroundColor(.adaptiveMutedRed)

                Text("$42.75")
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveMutedRed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingSM)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Color.adaptiveDepth1
                    Color.adaptiveMutedRed.opacity(0.1)
                }
            )
            .cornerRadius(.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 2, y: 4)
        }
        .padding(.horizontal, .paddingScreen)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.adaptiveDepth0)
    .preferredColorScheme(.light)
}

#Preview("Balance Cards - Dark") {
    VStack(spacing: .spacingLG) {
        HStack(spacing: .spacingSM) {
            // "You are owed" card
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("You are owed")
                    .font(.captionDynamic)
                    .foregroundColor(.adaptiveMutedGreen)

                Text("$156.50")
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveMutedGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingSM)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Color.adaptiveDepth1
                    Color.adaptiveMutedGreen.opacity(0.1)
                }
            )
            .cornerRadius(.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 2, y: 4)

            // "You owe" card
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("You owe")
                    .font(.captionDynamic)
                    .foregroundColor(.adaptiveMutedRed)

                Text("$42.75")
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveMutedRed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingSM)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Color.adaptiveDepth1
                    Color.adaptiveMutedRed.opacity(0.1)
                }
            )
            .cornerRadius(.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 2, y: 4)
        }
        .padding(.horizontal, .paddingScreen)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.adaptiveDepth0)
    .preferredColorScheme(.dark)
}

#Preview("Session Recovery Banner") {
    SessionRecoveryBanner(
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Tab Bar") {
    VStack {
        Spacer()
        TabBarView(selectedTab: .constant("home"))
    }
    .background(Color.adaptiveDepth0)
}

// MARK: - Deep Link Coordinator
// DeepLinkCoordinator and DeepLinkDestination extracted to Services/DeepLinkCoordinator.swift
