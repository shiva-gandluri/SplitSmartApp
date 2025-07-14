import SwiftUI

// MARK: - UI Components matching React designs exactly

struct UIHomeScreen: View {
    let onCreateNew: () -> Void
    
    // Simulate multiple transactions per person to show aggregated amounts
    private let allTransactions = [
        UITransaction(personName: "Sarah Chen", amount: 15.75, description: "Dinner at Olive Garden"),
        UITransaction(personName: "Sarah Chen", amount: 12.38, description: "Movie tickets"),
        UITransaction(personName: "Mike Johnson", amount: 25.00, description: "Grocery shopping"),
        UITransaction(personName: "Mike Johnson", amount: 17.50, description: "Gas split"),
        UITransaction(personName: "David Kim", amount: 8.25, description: "Coffee and Snacks"),
        UITransaction(personName: "David Kim", amount: 7.50, description: "Lunch yesterday")
    ]
    
    // People who owe me (I paid, they owe me back) - aggregated amounts
    private var peopleWhoOweMe: [UIPersonDebt] {
        let oweMeNames = ["Sarah Chen", "Mike Johnson"]
        return oweMeNames.map { name in
            let total = allTransactions
                .filter { $0.personName == name }
                .reduce(0) { $0 + $1.amount }
            let color: Color = name == "Sarah Chen" ? .green : .purple
            return UIPersonDebt(name: name, total: total, color: color)
        }
    }
    
    // People I owe (they paid, I owe them back) - aggregated amounts
    private var peopleIOwe: [UIPersonDebt] {
        let iOweNames = ["David Kim"]
        return iOweNames.map { name in
            let total = allTransactions
                .filter { $0.personName == name }
                .reduce(0) { $0 + $1.amount }
            return UIPersonDebt(name: name, total: total, color: .yellow)
        }
    }
    
    var totalOwed: Double {
        peopleWhoOweMe.reduce(0) { $0 + $1.total }
    }
    
    var totalOwe: Double {
        peopleIOwe.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
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

// MARK: - Data Models are now in Models/DataModels.swift

// MARK: - Scan Screen
// UIScanScreen is now in Views/ScanView.swift

// MARK: - Assign Screen

struct UIAssignScreen: View {
    let onContinue: () -> Void
    
    @State private var participants: [UIParticipant] = [
        UIParticipant(id: 1, name: "You", color: .blue),
        UIParticipant(id: 2, name: "Sarah", color: .green)
    ]
    
    @State private var items: [UIItem] = [
        UIItem(id: 1, name: "Pasta Carbonara", price: 16.95, assignedTo: nil),
        UIItem(id: 2, name: "Caesar Salad", price: 12.50, assignedTo: nil),
        UIItem(id: 3, name: "Garlic Bread", price: 5.95, assignedTo: nil),
        UIItem(id: 4, name: "Tiramisu", price: 8.75, assignedTo: nil),
        UIItem(id: 5, name: "Tax", price: 3.53, assignedTo: nil),
        UIItem(id: 6, name: "Tip (18%)", price: 7.95, assignedTo: nil)
    ]
    
    @State private var newParticipantName = ""
    @State private var showAddParticipant = false
    
    let colors: [Color] = [.blue, .green, .purple, .pink, .yellow, .red]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Assign Items")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Participants Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Participants")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: {
                            showAddParticipant = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .font(.caption)
                                Text("Add")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if showAddParticipant {
                        HStack {
                            TextField("Enter name", text: $newParticipantName)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                            
                            Button("Add") {
                                handleAddParticipant()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Participants chips
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(participants) { participant in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(participant.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption2)
                                    )
                                Text(participant.name)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Items Section
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt Items")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Drag items to assign them or tap to select")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    ForEach($items) { $item in
                        UIItemAssignCard(item: $item, participants: participants)
                            .padding(.horizontal)
                    }
                }
                
                Button(action: {
                    splitSharedItems()
                    onContinue()
                }) {
                    HStack {
                        Text("Continue to Summary")
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
    
    private func handleAddParticipant() {
        if !newParticipantName.trimmingCharacters(in: .whitespaces).isEmpty {
            let newId = (participants.map { $0.id }.max() ?? 0) + 1
            let colorIndex = participants.count % colors.count
            participants.append(UIParticipant(
                id: newId,
                name: newParticipantName.trimmingCharacters(in: .whitespaces),
                color: colors[colorIndex]
            ))
            newParticipantName = ""
            showAddParticipant = false
        }
    }
    
    private func splitSharedItems() {
        for index in items.indices {
            if items[index].assignedTo == nil && (items[index].name == "Tax" || items[index].name == "Tip (18%)") {
                items[index].name += " (Split equally)"
            }
        }
    }
}

// UIParticipant and UIItem are now in Models/DataModels.swift

struct UIItemAssignCard: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    
    var assignedParticipant: UIParticipant? {
        participants.first { $0.id == item.assignedTo }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .fontWeight(.medium)
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let assigned = assignedParticipant {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assigned.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            )
                        Text(assigned.name)
                            .font(.caption)
                    }
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            if assignedParticipant == nil {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(participants) { participant in
                        Button(participant.name) {
                            item.assignedTo = participant.id
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(participant.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(assignedParticipant != nil ? Color.gray.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(assignedParticipant != nil ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Summary Screen

struct UISummaryScreen: View {
    let onDone: () -> Void
    
    // Mock data exactly matching UI/SummaryScreen.tsx
    let summary = UISummary(
        restaurant: "Italian Restaurant",
        date: "June 15, 2023",
        total: 55.63,
        paidBy: "You",
        participants: [
            UISummaryParticipant(id: 1, name: "You", color: .blue, owes: 0, gets: 28.13),
            UISummaryParticipant(id: 2, name: "Sarah", color: .green, owes: 28.13, gets: 0)
        ],
        breakdown: [
            UIBreakdown(id: 1, name: "You", color: .blue, items: [
                UIBreakdownItem(name: "Pasta Carbonara", price: 16.95),
                UIBreakdownItem(name: "Tiramisu", price: 8.75)
            ]),
            UIBreakdown(id: 2, name: "Sarah", color: .green, items: [
                UIBreakdownItem(name: "Caesar Salad", price: 12.50),
                UIBreakdownItem(name: "Garlic Bread", price: 5.95)
            ]),
            UIBreakdown(id: 3, name: "Shared", color: .gray, items: [
                UIBreakdownItem(name: "Tax (Split equally)", price: 3.53),
                UIBreakdownItem(name: "Tip (18%) (Split equally)", price: 7.95)
            ])
        ]
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(summary.restaurant) • \(summary.date)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Bill paid by section
                VStack(spacing: 8) {
                    Text("Bill paid by \(summary.paidBy)")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    HStack {
                        Text("Total amount:")
                        Spacer()
                        Text("$\(summary.total, specifier: "%.2f")")
                            .fontWeight(.bold)
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
                
                // Who pays whom section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Who pays whom")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ForEach(summary.participants.filter { $0.owes > 0 }) { participant in
                        HStack {
                            // From person
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(participant.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                    )
                                Text(participant.name)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            // To person (You)
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                    )
                                Text("You")
                            }
                            
                            Spacer()
                            
                            Text("$\(participant.owes, specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                }
                
                // Detailed breakdown section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detailed breakdown")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ForEach(summary.breakdown) { person in
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
                                Text("$\(person.items.reduce(0) { $0 + $1.price }, specifier: "%.2f")")
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
                
                Button(action: onDone) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Mark as Settled")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
}

// UISummary, UISummaryParticipant, UIBreakdown, and UIBreakdownItem are now in Models/DataModels.swift

// MARK: - Profile Screen

struct UIProfileScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // User info section
                HStack(spacing: 16) {
                    AsyncImage(url: authViewModel.user?.photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.user?.displayName ?? "User")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(authViewModel.user?.email ?? "No email")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Menu items
                VStack(spacing: 8) {
                    UIProfileMenuItem(
                        icon: "gearshape",
                        title: "Account Settings"
                    )
                    
                    UIProfileMenuItem(
                        icon: "bell",
                        title: "Notifications"
                    )
                    
                    UIProfileMenuItem(
                        icon: "creditcard",
                        title: "Payment Methods"
                    )
                    
                    UIProfileMenuItem(
                        icon: "questionmark.circle",
                        title: "Help & Support"
                    )
                }
                .padding(.horizontal)
                
                // Log out button
                Button(action: {
                    authViewModel.signOut()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Log Out")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // App info
                VStack(spacing: 4) {
                    Text("SplitSmart v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("© 2023 SplitSmart Inc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            .padding(.top)
        }
    }
}

struct UIProfileMenuItem: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    Text(title)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
}