import SwiftUI
import FirebaseFirestore

// Ensure DataModels types are available
// Note: In same target, should be automatically available

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
                UIHomeScreen(session: billSplitSession, billManager: billManager, authViewModel: authViewModel) { 
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
                HistoryView(billManager: billManager)
                    .environmentObject(authViewModel)
            case "profile":
                UIProfileScreen()
                    .environmentObject(authViewModel)
            default:
                UIHomeScreen(session: billSplitSession, billManager: billManager, authViewModel: authViewModel) { 
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

// MARK: - UIHomeScreen with Recent Bills

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
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("SplitSmart")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal)
                    
                    // Loading indicator for balance updates
                    if billManager.isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading balances...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Balance Cards with exact React colors
                    HStack(spacing: 12) {
                        // "You are owed" card - matching React green-50, green-100, green-800
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You are owed")
                                .font(.caption)
                                .foregroundColor(Color(red: 22/255, green: 101/255, blue: 52/255)) // green-800
                            
                            Text("$\(totalOwed, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 22/255, green: 101/255, blue: 52/255)) // green-800
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(red: 240/255, green: 253/255, blue: 244/255)) // green-50
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 187/255, green: 247/255, blue: 208/255), lineWidth: 1) // green-100
                        )
                        .cornerRadius(12)
                        
                        // "You owe" card - matching React red-50, red-100, red-800
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You owe")
                                .font(.caption)
                                .foregroundColor(Color(red: 153/255, green: 27/255, blue: 27/255)) // red-800
                            
                            Text("$\(totalOwe, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 153/255, green: 27/255, blue: 27/255)) // red-800
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(red: 254/255, green: 242/255, blue: 242/255)) // red-50
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 254/255, green: 202/255, blue: 202/255), lineWidth: 1) // red-100
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Create New Split Button
                    Button(action: onCreateNew) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Create New Split")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // People who owe you - simple list
                    if !peopleWhoOweMe.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                                Text("People who owe you")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(peopleWhoOweMe) { person in
                                    HStack {
                                        Circle()
                                            .fill(person.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            )
                                        
                                        Text(person.name)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("$\(person.total, specifier: "%.2f")")
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // People you owe - simple list
                    if !peopleIOwe.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                Text("People you owe")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(peopleIOwe) { person in
                                    HStack {
                                        Circle()
                                            .fill(person.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            )
                                        
                                        Text(person.name)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("$\(person.total, specifier: "%.2f")")
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // All settled up message
                    if peopleWhoOweMe.isEmpty && peopleIOwe.isEmpty {
                        VStack(spacing: 8) {
                            Text("All settled up!")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("You have no outstanding balances")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color.gray.opacity(0.05))
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
    
    private var isCreator: Bool {
        authViewModel.user?.uid == bill.createdBy
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(bill.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("$\(bill.totalAmount, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Created on \(bill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items (\(bill.items.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(bill.items) { item in
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
                .cornerRadius(12)
                
                // Action buttons for creators
                if isCreator && !bill.isDeleted {
                    BillActionButtons(bill: bill, authViewModel: authViewModel, billManager: billManager)
                }
                
                if bill.isDeleted {
                    Text("This bill has been deleted")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
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
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button("Delete Bill") {
                showingDeleteAlert = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
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
            print("✅ Bill deleted successfully")
            
            // Force refresh the bill manager to ensure balance updates immediately
            if let userId = authViewModel.user?.uid {
                print("🔄 Force refreshing BillManager after deletion")
                billManager.setCurrentUser(userId)
            }
        } catch {
            print("❌ Failed to delete bill: \(error.localizedDescription)")
            // TODO: Show error alert to user
        }
    }
}

// MARK: - Bill Edit Flow (using existing create bill screens)

struct BillEditFlow: View {
    let bill: Bill
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var billManager: BillManager
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var editSession = BillSplitSession()
    @State private var currentStep = "confirm" // confirm -> assign -> summary
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case "confirm":
                    BillEditConfirmationView(
                        bill: bill,
                        session: editSession,
                        onContinue: {
                            currentStep = "assign"
                        }
                    )
                case "assign":
                    UIAssignScreen(
                        session: editSession,
                        contactsManager: contactsManager,
                        onContinue: {
                            editSession.completeAssignment()
                            currentStep = "summary"
                        }
                    )
                    .environmentObject(authViewModel)
                case "summary":
                    BillEditSummaryScreen(
                        bill: bill,
                        session: editSession,
                        onDone: {
                            editSession.completeSession()
                            dismiss()
                        },
                        contactsManager: contactsManager,
                        authViewModel: authViewModel,
                        billManager: billManager
                    )
                default:
                    BillEditConfirmationView(
                        bill: bill,
                        session: editSession,
                        onContinue: {
                            currentStep = "assign"
                        }
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadBillIntoSession()
        }
    }
    
    private func loadBillIntoSession() {
        // Convert existing Bill data into BillSplitSession format
        
        // 1. Set totals and tax/tip (reconstruct from bill data)
        editSession.confirmedTotal = bill.totalAmount
        editSession.identifiedTotal = bill.totalAmount
        editSession.confirmedTax = 0.0 // We'll let user adjust if needed
        editSession.confirmedTip = 0.0 // We'll let user adjust if needed
        editSession.expectedItemCount = bill.items.count
        
        // 2. Convert BillItems to ReceiptItems (for assignment screen)
        let receiptItems = bill.items.map { billItem in
            ReceiptItem(name: billItem.name, price: billItem.price)
        }
        editSession.scannedItems = receiptItems
        
        // 2.5. Set rawReceiptText to prevent UIAssignScreen from clearing our data
        // Create a synthetic receipt text from the existing bill items
        editSession.rawReceiptText = receiptItems.map { "\($0.name) \($0.price)" }.joined(separator: "\n")
        
        // 2.6. Set comparison arrays to prevent loading screens in UIAssignScreen
        // In edit mode, we already have the final items, so set both regex and LLM results to the same
        editSession.regexDetectedItems = receiptItems
        editSession.llmDetectedItems = receiptItems
        
        // 3. Set participants (convert BillParticipants to UIParticipants)
        var uiParticipants: [UIParticipant] = []
        
        // Add current user as "You" first
        if let currentUserId = authViewModel.user?.uid,
           let currentUser = bill.participants.first(where: { $0.id == currentUserId }) {
            uiParticipants.append(UIParticipant(id: 1, name: "You", color: .blue))
        }
        
        // Add other participants
        var participantId = 2
        for participant in bill.participants {
            if participant.id != authViewModel.user?.uid {
                let colors: [Color] = [.red, .green, .orange, .purple, .pink, .cyan]
                uiParticipants.append(UIParticipant(
                    id: participantId,
                    name: participant.displayName,
                    color: colors[participantId % colors.count]
                ))
                participantId += 1
            }
        }
        
        editSession.participants = uiParticipants
        
        // 4. Set who paid the bill
        if let payerParticipant = bill.participants.first(where: { $0.id == bill.paidBy }),
           let payerUIParticipant = uiParticipants.first(where: { participant in
               (participant.name == "You" && payerParticipant.id == authViewModel.user?.uid) ||
               (participant.name == payerParticipant.displayName)
           }) {
            editSession.paidByParticipantID = payerUIParticipant.id
        }
        
        // 5. Set bill name
        editSession.billName = bill.billName ?? ""
        
        // 5.5. Set a flag to indicate this is edit mode to prevent reprocessing
        editSession.sessionState = .assigning // Skip the processing phase
        
        // 6. Convert assignments
        editSession.assignedItems = bill.items.enumerated().map { index, billItem in
            UIItem(
                id: index,
                name: billItem.name,
                price: billItem.price,
                assignedTo: nil,
                assignedToParticipants: Set(billItem.participantIDs.compactMap { billParticipantId in
                    // Map BillParticipant IDs to UIParticipant IDs
                    if billParticipantId == authViewModel.user?.uid {
                        return 1 // "You" is always ID 1
                    } else {
                        // Find the UIParticipant with matching name
                        if let billParticipant = bill.participants.first(where: { $0.id == billParticipantId }),
                           let uiParticipant = uiParticipants.first(where: { $0.name == billParticipant.displayName }) {
                            return uiParticipant.id
                        }
                    }
                    return nil
                }),
                confidence: .high,
                originalDetectedName: nil,
                originalDetectedPrice: nil
            )
        }
        
        print("✅ Loaded bill into edit session:")
        print("  - Items: \(editSession.assignedItems.count)")
        print("  - Participants: \(editSession.participants.count)")
        print("  - Total: $\(String(format: "%.2f", editSession.confirmedTotal))")
        print("  - Paid by: \(editSession.paidByParticipantID?.description ?? "nil")")
    }
}

// MARK: - Bill Edit Confirmation View (replaces scan screen for editing)

struct BillEditConfirmationView: View {
    let bill: Bill
    @ObservedObject var session: BillSplitSession
    let onContinue: () -> Void
    
    @State private var editedTax: String = "0.00"
    @State private var editedTip: String = "0.00"
    @State private var editedTotal: String = ""
    @State private var editedItemCount: String = ""
    
    private var calculatedSubtotal: Double {
        session.scannedItems.reduce(0) { $0 + $1.price }
    }
    
    private var totalWithTaxAndTip: Double {
        let tax = Double(editedTax) ?? 0.0
        let tip = Double(editedTip) ?? 0.0
        return calculatedSubtotal + tax + tip
    }
    
    private var totalsMatch: Bool {
        let enteredTotal = Double(editedTotal) ?? 0.0
        return abs(totalWithTaxAndTip - enteredTotal) <= 0.01
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Verify Bill Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                Text("Review and adjust the bill details before proceeding to assign items.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Items Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items (\(session.scannedItems.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(session.scannedItems.indices, id: \.self) { index in
                            HStack {
                                TextField("Item name", text: .constant(session.scannedItems[index].name))
                                    .fontWeight(.medium)
                                    .disabled(true)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("$\(session.scannedItems[index].price, specifier: "%.2f")")
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Totals Section (similar to OCR confirmation)
                VStack(spacing: 16) {
                    Text("Verify Totals")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Subtotal (calculated)
                    HStack {
                        Text("Subtotal:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("$\(calculatedSubtotal, specifier: "%.2f")")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    // Tax (editable)
                    HStack {
                        Text("Tax:")
                            .fontWeight(.medium)
                        Spacer()
                        HStack {
                            Text("$")
                            TextField("0.00", text: $editedTax)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Tip (editable)
                    HStack {
                        Text("Tip:")
                            .fontWeight(.medium)
                        Spacer()
                        HStack {
                            Text("$")
                            TextField("0.00", text: $editedTip)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    Divider()
                    
                    // Calculated total
                    HStack {
                        Text("Calculated Total:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("$\(totalWithTaxAndTip, specifier: "%.2f")")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    // Receipt total verification
                    HStack {
                        Text("Receipt Total:")
                            .fontWeight(.semibold)
                        Spacer()
                        HStack {
                            Text("$")
                            TextField("\(bill.totalAmount, specifier: "%.2f")", text: $editedTotal)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Item count verification
                    HStack {
                        Text("Number of Items:")
                            .fontWeight(.medium)
                        Spacer()
                        TextField("\(session.scannedItems.count)", text: $editedItemCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Validation message
                    if !totalsMatch {
                        Text("⚠️ Totals don't match. Please verify the amounts above.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 8)
                    } else {
                        Text("✅ Totals match!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Continue Button
                Button(action: {
                    // Update session with confirmed values
                    session.confirmedTax = Double(editedTax) ?? 0.0
                    session.confirmedTip = Double(editedTip) ?? 0.0
                    session.confirmedTotal = Double(editedTotal) ?? totalWithTaxAndTip
                    session.expectedItemCount = Int(editedItemCount) ?? session.scannedItems.count
                    session.identifiedTotal = session.confirmedTotal
                    
                    onContinue()
                }) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Continue to Assign Items")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(totalsMatch ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!totalsMatch)
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .navigationTitle("Edit Bill")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize editable fields with current values
            editedTax = String(format: "%.2f", session.confirmedTax)
            editedTip = String(format: "%.2f", session.confirmedTip) 
            editedTotal = String(format: "%.2f", session.confirmedTotal)
            editedItemCount = "\(session.expectedItemCount)"
        }
    }
}

// MARK: - Bill Edit Summary Screen (updates existing bill instead of creating new)

struct BillEditSummaryScreen: View {
    let bill: Bill
    let session: BillSplitSession
    let onDone: () -> Void
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var billManager: BillManager
    
    @StateObject private var billService = BillService()
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var showingError = false
    
    // Use similar layout to UISummaryScreen but for updating
    private var defaultBillName: String {
        let itemCount = session.assignedItems.count
        return itemCount == 1 ? session.assignedItems[0].name : "\(itemCount) items"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Update Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Bill changes • \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Bill name editing section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bill Name")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Optional")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Enter bill name (e.g., \"Dinner at Olive Garden\")", text: Binding(
                        get: { session.billName },
                        set: { session.billName = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                    
                    Text("Leave empty to use default: \"\(defaultBillName)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Bill paid by section
                VStack(spacing: 12) {
                    HStack {
                        if let paidByID = session.paidByParticipantID,
                           let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {
                            Circle()
                                .fill(paidByParticipant.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                )
                            Text("Bill paid by \(paidByParticipant.name)")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        } else {
                            Text("Bill paid by Unknown")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    
                    HStack {
                        Text("Total amount:")
                        Spacer()
                        Text("$\(session.totalAmount, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.blue)
                    
                    HStack {
                        Text("Date & Time:")
                        Spacer()
                        Text("\(Date().formatted(date: .abbreviated, time: .shortened))")
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
                
                // Who Owes Whom section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Who Owes Whom")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    if let paidByID = session.paidByParticipantID,
                       let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {
                        
                        // Calculate individual debts to the payer
                        ForEach(session.individualDebts.sorted(by: { $0.key < $1.key }), id: \.key) { participantID, amountOwed in
                            if let debtor = session.participants.first(where: { $0.id == Int(participantID) }),
                               amountOwed > 0.01 { // Only show significant amounts
                                
                                HStack {
                                    // From person (debtor)
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(debtor.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                                    .font(.caption)
                                            )
                                        Text(debtor.name)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 8)
                                    
                                    // To person (payer)
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(paidByParticipant.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                                    .font(.caption)
                                            )
                                        Text(paidByParticipant.name)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Spacer()
                                    
                                    // Amount owed
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("$\(amountOwed, specifier: "%.2f")")
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Text("owes")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // Show "No debts" message if everyone paid their share
                        if session.individualDebts.allSatisfy({ $0.value <= 0.01 }) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Everyone paid their share!")
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Detailed breakdown section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detailed breakdown")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ForEach(session.breakdownSummaries) { person in
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Circle()
                                    .fill(person.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Group {
                                            if person.name == "Shared" {
                                                Text("S")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            } else {
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                                    .font(.caption2)
                                            }
                                        }
                                    )
                                Text(person.name)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            
                            // Items
                            ForEach(person.items, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text("$\(item.price, specifier: "%.2f")")
                                        .fontWeight(.medium)
                                }
                                .padding()
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.gray.opacity(0.2)),
                                    alignment: .bottom
                                )
                            }
                            
                            // Subtotal
                            HStack {
                                Text("Subtotal")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(person.items.reduce(0) { $0.currencyAdd($1.price) }, specifier: "%.2f")")
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                        }
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
                
                // Update Bill Button with loading state
                Button(action: {
                    print("🔵 Update Bill button tapped")
                    print("🔍 Session ready: \(session.isReadyForBillCreation)")
                    print("🔍 PaidBy ID: \(session.paidByParticipantID?.description ?? "nil")")
                    print("🔍 Items count: \(session.assignedItems.count)")
                    Task {
                        await updateBill()
                    }
                }) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isUpdating ? "Updating Bill..." : "Update Bill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isUpdating ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isUpdating || !session.isReadyForBillCreation)
                .padding(.horizontal)
                
                // Show error if bill update fails
                if let error = updateError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Update Bill")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Bill Update Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                updateError = nil
            }
        } message: {
            Text(updateError ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Bill Update Logic
    @MainActor
    private func updateBill() async {
        guard session.isReadyForBillCreation else {
            updateError = "Session is not ready for bill update"
            showingError = true
            return
        }
        
        isUpdating = true
        updateError = nil
        
        do {
            print("🔵 Starting Firebase bill update process...")
            
            // Convert session data back to BillItem and BillParticipant format
            let updatedItems = session.assignedItems.map { assignedItem in
                BillItem(
                    name: assignedItem.name,
                    price: assignedItem.price,
                    participantIDs: assignedItem.assignedToParticipants.compactMap { uiParticipantId in
                        // Map UIParticipant IDs back to BillParticipant IDs
                        print("🔍 Mapping UIParticipant ID \(uiParticipantId) back to Firebase UID")
                        
                        if uiParticipantId == 1 { // "You" is always ID 1
                            let yourUID = authViewModel.user?.uid
                            print("🔍 UIParticipant ID 1 ('You') → \(yourUID ?? "nil")")
                            return yourUID
                        } else {
                            // Find the original BillParticipant with matching name
                            if let uiParticipant = session.participants.first(where: { $0.id == uiParticipantId }) {
                                print("🔍 Found UIParticipant: \(uiParticipant.name)")
                                print("🔍 Available BillParticipants for item: \(bill.participants.map { "\($0.displayName) (\($0.id))" })")
                                
                                // Try exact name match first
                                if let billParticipant = bill.participants.first(where: { $0.displayName == uiParticipant.name }) {
                                    print("🔍 ✅ Exact name match: \(uiParticipant.name) → \(billParticipant.id)")
                                    return billParticipant.id
                                }
                                
                                // Try case-insensitive match
                                if let billParticipant = bill.participants.first(where: { 
                                    $0.displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                                    uiParticipant.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) 
                                }) {
                                    print("🔍 ✅ Case-insensitive name match: \(uiParticipant.name) → \(billParticipant.id)")
                                    return billParticipant.id
                                }
                                
                                // If name matching fails, use the other participant (fallback for 2-person bills)
                                let otherParticipant = bill.participants.first(where: { $0.id != authViewModel.user?.uid })
                                if let other = otherParticipant {
                                    print("🔍 ⚠️ Fallback: Using other participant \(other.displayName) → \(other.id)")
                                    print("🔍 This fallback might cause incorrect item assignments!")
                                    return other.id
                                }
                                
                                print("❌ No matching BillParticipant found for UIParticipant: \(uiParticipant.name)")
                            } else {
                                print("❌ UIParticipant ID \(uiParticipantId) not found in session.participants")
                            }
                        }
                        return nil
                    }
                )
            }
            
            let paidByParticipantId: String
            if let paidByID = session.paidByParticipantID {
                print("🔍 Mapping payer UIParticipant ID \(paidByID) to Firebase UID")
                
                if paidByID == 1 { // "You"
                    paidByParticipantId = authViewModel.user?.uid ?? ""
                    print("🔍 Payer is 'You' → \(paidByParticipantId)")
                } else {
                    // Find the original BillParticipant with matching name
                    if let uiParticipant = session.participants.first(where: { $0.id == paidByID }) {
                        print("🔍 Found payer UIParticipant: \(uiParticipant.name)")
                        print("🔍 Available BillParticipants: \(bill.participants.map { "\($0.displayName) (\($0.id))" })")
                        
                        // Try exact name match first
                        if let billParticipant = bill.participants.first(where: { $0.displayName == uiParticipant.name }) {
                            paidByParticipantId = billParticipant.id
                            print("🔍 ✅ Exact name match for payer: \(uiParticipant.name) → \(billParticipant.id)")
                        } else {
                            // Try case-insensitive match
                            if let billParticipant = bill.participants.first(where: { 
                                $0.displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                                uiParticipant.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) 
                            }) {
                                paidByParticipantId = billParticipant.id
                                print("🔍 ✅ Case-insensitive name match for payer: \(uiParticipant.name) → \(billParticipant.id)")
                            } else {
                                // Final fallback: find the other participant (non-current user)
                                let otherParticipant = bill.participants.first(where: { $0.id != authViewModel.user?.uid })
                                paidByParticipantId = otherParticipant?.id ?? authViewModel.user?.uid ?? ""
                                print("🔍 ⚠️ No name match found, using other participant fallback → \(paidByParticipantId)")
                                print("🔍 This might cause incorrect calculations!")
                            }
                        }
                    } else {
                        paidByParticipantId = authViewModel.user?.uid ?? ""
                        print("❌ Payer UIParticipant not found, defaulting to current user")
                    }
                }
            } else {
                paidByParticipantId = bill.paidBy // Keep original payer
                print("🔍 No payer change, keeping original: \(paidByParticipantId)")
            }
            
            // Update bill using BillService
            try await billService.updateBill(
                billId: bill.id,
                billName: session.billName.isEmpty ? defaultBillName : session.billName,
                items: updatedItems,
                participants: bill.participants, // Keep same participants
                paidByParticipantId: paidByParticipantId,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )
            
            print("✅ Bill update successful! ID: \(bill.id)")
            
            // 🔧 CRITICAL DEBUG: Final verification of update results
            print("🔧 FINAL VERIFICATION:")
            print("🔧   - Bill ID: \(bill.id)")
            print("🔧   - Updated payer: \(paidByParticipantId)")
            print("🔧   - Current user UID: \(authViewModel.user?.uid ?? "nil")")
            print("🔧   - If payer changed FROM current user TO other person:")
            print("🔧     Current user should now owe money to the new payer")
            print("🔧   - BillManager should refresh and show updated balances on home screen")
            
            // Force refresh BillManager to ensure UI updates
            await billManager.refreshBills()
            print("🔧 Forced BillManager refresh completed")
            
            // Call the completion handler
            onDone()
            
        } catch {
            print("❌ Bill update failed: \(error.localizedDescription)")
            updateError = error.localizedDescription
            showingError = true
        }
        
        isUpdating = false
    }
}

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
                .foregroundColor(.red)
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
                        .foregroundColor(.red)
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
                            .foregroundColor(.green)
                    } else if owedAmount > 0.01 {
                        Text("You owe $\(owedAmount, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.red)
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
                    .foregroundColor(.blue)
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

#Preview {
    ContentView()
}