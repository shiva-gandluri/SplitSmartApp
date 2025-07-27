import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @State private var selectedTab = "home"
    @State private var isKeyboardVisible = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var billSplitSession = BillSplitSession()
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var billManager = BillManager()
    
    var showBackButton: Bool {
        return ["scan", "assign", "summary"].contains(selectedTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button for navigation flows
            if showBackButton {
                HStack {
                    Button(action: handleBackAction) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    Spacer()
                }
            }
            
            switch selectedTab {
            case "home":
                UIHomeScreen(session: billSplitSession, billManager: billManager) { 
                    billSplitSession.startNewSession()
                    selectedTab = "scan" 
                }
            case "groups":
                UIGroupsScreen()
            case "scan":
                UIScanScreen(session: billSplitSession) { 
                    selectedTab = "assign" 
                }
            case "assign":
                UIAssignScreen(session: billSplitSession, contactsManager: contactsManager) { 
                    billSplitSession.completeAssignment()
                    selectedTab = "summary" 
                }
            case "summary":
                UISummaryScreen(
                    session: billSplitSession,
                    onDone: {
                        billSplitSession.completeSession()
                        selectedTab = "home" 
                    },
                    contactsManager: contactsManager,
                    authViewModel: authViewModel
                )
            case "history":
                UIHistoryScreen(billManager: billManager)
                    .environmentObject(authViewModel)
            case "profile":
                UIProfileScreen()
                    .environmentObject(authViewModel)
            default:
                UIHomeScreen(session: billSplitSession, billManager: billManager) { 
                    billSplitSession.startNewSession()
                    selectedTab = "scan" 
                }
            }
            
            // Only show TabBar when keyboard is not visible
            if !isKeyboardVisible {
                TabBarView(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            setupKeyboardObservers()
            
            // Initialize managers with current user
            if let userId = authViewModel.user?.uid {
                contactsManager.setCurrentUser(userId)
                billManager.setCurrentUser(userId)
            }
        }
        .onChange(of: authViewModel.user?.uid) { oldUserId, newUserId in
            // Handle user changes (logout/login with different user)
            if let userId = newUserId {
                contactsManager.setCurrentUser(userId)
                billManager.setCurrentUser(userId)
            } else {
                contactsManager.clearCurrentUser()
                billManager.clearCurrentUser()
            }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
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

struct TabBarView: View {
    @Binding var selectedTab: String
    
    var body: some View {
        HStack {
            TabButton(icon: "house.fill", label: "Home", isSelected: selectedTab == "home") {
                selectedTab = "home"
            }
            TabButton(icon: "person.2.fill", label: "Groups", isSelected: selectedTab == "groups") {
                selectedTab = "groups"
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
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
}

// TabButton is now in Components/TabButton.swift

struct UIGroupsScreen: View {
    var body: some View {
        ScrollView {
            VStack {
                Text("Groups")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("Groups functionality coming soon!")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
    }
}

struct UIHistoryScreen: View {
    @ObservedObject var billManager: BillManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("History")
                        .font(.largeTitle)
                        .fontWeight(.bold)
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
                                NavigationLink(destination: BillDetailView(bill: bill)) {
                                    BillHistoryCard(bill: bill)
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
                            .foregroundColor(.red)
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
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
                                .fill(Color.blue) // Default color since we don't store colors in Bill
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
                    .foregroundColor(.blue)
                    
                    HStack {
                        Text("Date & Time:")
                        Spacer()
                        Text("\(formatFullDate(bill.date))")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
                                        .fill(Color.green) // Default color
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
                                        .fill(Color.blue) // Payer color
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
                                    .foregroundColor(.green)
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
                        ItemDetailCard(item: item, bill: bill)
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
                    .foregroundColor(.blue)
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
        if participantID == "1" {
            return "You"
        } else {
            return bill.participants.first { $0.id != bill.paidBy }?.displayName
        }
    }
    
    private func getColorForParticipant(_ participantID: String) -> Color {
        if participantID == "1" {
            return .blue
        } else {
            return .green
        }
    }
}

// ParticipantDebtCard removed - replaced with integrated "Who Owes Whom" design

#Preview {
    ContentView()
}