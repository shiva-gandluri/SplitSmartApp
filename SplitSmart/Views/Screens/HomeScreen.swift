import SwiftUI

/**
 * Home Screen - Main Dashboard View
 * 
 * The primary interface displaying user's financial overview and quick actions.
 * 
 * Features:
 * - Real-time balance calculations from BillManager
 * - Visual debt breakdown with color-coded cards
 * - Quick "Create New Split" action
 * - Detailed lists of who owes whom
 * - All-settled-up status display
 * 
 * Architecture: MVVM with ObservableObject integration
 * Design: Matches React web app color scheme for consistency
 */

struct UIHomeScreen: View {
    let session: BillSplitSession
    @ObservedObject var billManager: BillManager
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