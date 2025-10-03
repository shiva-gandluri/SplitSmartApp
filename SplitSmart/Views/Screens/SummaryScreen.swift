import SwiftUI

/**
 * Summary Screen - Final Bill Review and Creation Interface
 * 
 * Comprehensive bill summary displaying debt calculations and detailed breakdowns.
 * 
 * Features:
 * - Editable bill name with smart defaults
 * - Bill payer and total amount display
 * - Individual debt calculations (who owes whom)
 * - Detailed per-participant item breakdown
 * - Async Firebase bill creation with error handling
 * - Loading states and validation feedback
 * 
 * Architecture: MVVM with async Firebase operations
 * Data Flow: Session → BillService → Firebase Firestore
 */

struct UISummaryScreen: View {
    let session: BillSplitSession
    let onDone: () -> Void
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var billService = BillService()
    @State private var isCreatingBill = false
    @State private var billCreationError: String?
    @State private var showingError = false
    @State private var createdBill: Bill?
    
    var defaultBillName: String {
        let itemCount = session.assignedItems.count
        return itemCount == 1 ? session.assignedItems[0].name : "\(itemCount) items"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Receipt • \(Date().formatted(date: .abbreviated, time: .omitted))")
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
                
                // Who Owes Whom section - Individual debts (not net amounts)
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
                    } else {
                        // Error state - no payer selected
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("Error: No payer selected")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
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
                
                // Add Bill Button with loading state
                Button(action: {
                    print("🔵 Add Bill button tapped")
                    print("🔍 Session ready: \(session.isReadyForBillCreation)")
                    print("🔍 PaidBy ID: \(session.paidByParticipantID?.description ?? "nil")")
                    print("🔍 Items count: \(session.assignedItems.count)")
                    Task {
                        await createBill()
                    }
                }) {
                    HStack {
                        if isCreatingBill {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(isCreatingBill ? "Creating Bill..." : "Add Bill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isCreatingBill ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isCreatingBill || !session.isReadyForBillCreation)
                .padding(.horizontal)
                
                // Show error if bill creation fails
                if let error = billCreationError {
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
        .alert("Bill Creation Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                billCreationError = nil
            }
        } message: {
            Text(billCreationError ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Bill Creation Logic
    @MainActor
    private func createBill() async {
        guard session.isReadyForBillCreation else {
            billCreationError = session.billCreationErrorMessage ?? "Session is not ready for bill creation"
            showingError = true
            return
        }
        
        isCreatingBill = true
        billCreationError = nil
        
        do {
            print("🔵 Starting Firebase bill creation process...")
            
            // Create bill using BillService
            let bill = try await billService.createBill(
                from: session,
                authViewModel: authViewModel,
                contactsManager: contactsManager
            )
            
            createdBill = bill
            print("✅ Bill creation successful! ID: \(bill.id)")

            // Clear saved session after successful bill creation
            do {
                try SessionPersistenceManager.shared.clearSession()
                print("🗑️ SummaryScreen: Cleared saved session after bill creation")
            } catch {
                print("⚠️ SummaryScreen: Failed to clear session - \(error.localizedDescription)")
                // Non-fatal error, continue anyway
            }

            // TODO: Phase 3 - Send push notifications here

            // Call the completion handler
            onDone()
            
        } catch {
            print("❌ Bill creation failed: \(error.localizedDescription)")
            
            // Check if it's a Firebase permissions error
            if error.localizedDescription.contains("Missing or insufficient permissions") {
                billCreationError = "Firebase Firestore permissions not configured. Please set up security rules to allow authenticated writes to the 'bills' and 'users' collections."
            } else {
                billCreationError = error.localizedDescription
            }
            showingError = true
        }
        
        isCreatingBill = false
    }
}