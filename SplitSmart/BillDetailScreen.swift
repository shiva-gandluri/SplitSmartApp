import SwiftUI
import FirebaseFirestore

/**
 * Bill Detail Screen - Detailed Bill View with Edit/Delete Capabilities
 * 
 * Comprehensive bill display with full CRUD operations for bill creators.
 * 
 * Features:
 * - Detailed bill information display
 * - Edit functionality for bill creators only
 * - Delete functionality with confirmation dialog
 * - Real-time debt recalculation on changes
 * - Participant notifications on updates
 * - Offline-first design with online requirement
 * 
 * Architecture: MVVM with async Firebase operations
 * Data Flow: BillManager → Firebase Firestore → Real-time updates
 */

struct BillDetailScreen: View {
    let bill: Bill
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var editSession = BillEditSession()
    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    // Computed properties
    private var isCreator: Bool {
        let result = authViewModel.user?.uid == bill.createdBy
        if let deletedBy = bill.deletedBy {
        }
        return result
    }
    
    private var billTotal: Double {
        bill.items.reduce(0) { $0 + $1.price }
    }
    
    private var creator: BillParticipant? {
        bill.participants.first { $0.id == bill.createdBy }
    }
    
    private var payer: BillParticipant? {
        bill.participants.first { $0.id == bill.paidBy }
    }
    
    var body: some View {

        return ScrollView {
            VStack(spacing: 24) {
                // Debug logging for deletion state
                Color.clear.onAppear {
                    if let deletedBy = bill.deletedBy, let deletedAt = bill.deletedAt {
                    }
                }

                // Deleted Bill Banner
                if bill.isDeleted {
                    deletedBillBanner
                }

                // Header Section
                headerSection

                // Bill Overview
                billOverviewSection

                // Participants & Debt Section
                participantsSection

                // Items Breakdown
                itemsSection

                // Action Buttons (only for creators of active bills)
                if isCreator && !bill.isDeleted {
                    actionButtons
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(bill.isDeleted ? "Deleted Bill" : "Bill Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditView) {
            BillEditView(
                bill: bill,
                editSession: editSession,
                billManager: billManager,
                authViewModel: authViewModel,
                onDismiss: {
                    showingEditView = false
                }
            )
        }
        .alert("Delete Bill", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteBill()
                }
            }
        } message: {
            Text("Are you sure you want to delete this bill? This action cannot be undone. All participants will be notified and balances will be recalculated.")
        }
        .alert("Delete Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            Text(deleteError ?? "")
        }
    }
    
    // MARK: - View Components

    private var deletedBillBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trash.slash.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("This bill has been deleted")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let deletedByName = bill.deletedByDisplayName,
                       let deletedAt = bill.deletedAt {
                        Text("Deleted by \(deletedByName) on \(deletedAt.dateValue().formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color.red)
            .cornerRadius(12)

            Text("This is a read-only view for your records. You cannot edit or restore this bill.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.billName ?? "Bill #\(bill.id.prefix(8))")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Created on \(bill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if bill.isDeleted {
                        HStack {
                            Image(systemName: "trash.slash")
                                .foregroundColor(.red)
                            Text("DELETED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    private var billOverviewSection: some View {
        VStack(spacing: 16) {
            // Total Amount
            HStack {
                Text("Total Amount:")
                    .font(.headline)
                Spacer()
                Text("$\(billTotal, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // Creator Info
            if let creator = creator {
                HStack {
                    Text("Created by:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        Text(creator.displayName)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
            
            // Payer Info
            if let payer = payer {
                HStack {
                    Text("Paid by:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "creditcard.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        Text(payer.displayName)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Owes What")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            let owedAmounts = BillCalculator.calculateOwedAmounts(bill: bill)
            
            if owedAmounts.isEmpty || owedAmounts.allSatisfy({ $0.value <= 0.01 }) {
                // All settled up
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("All settled up!")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Show debts
                ForEach(owedAmounts.sorted(by: { $0.key < $1.key }), id: \.key) { participantId, amount in
                    if let debtor = bill.participants.first(where: { $0.id == participantId }),
                       let payer = payer,
                       amount > 0.01 {
                        
                        HStack {
                            // Debtor
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                                Text(debtor.displayName)
                                    .fontWeight(.medium)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                            
                            // Payer
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                                Text(payer.displayName)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            // Amount
                            Text("$\(amount, specifier: "%.2f")")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items (\(bill.items.count))")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(bill.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .fontWeight(.medium)
                            
                            Text("Split among \(item.participantIDs.count) people")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("$\(item.price, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit Button
            Button(action: {
                editSession.loadBill(bill)
                showingEditView = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Bill")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }

            // Delete Button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(isDeleting ? "Deleting..." : "Delete Bill")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDeleting ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    @MainActor
    private func deleteBill() async {
        isDeleting = true
        deleteError = nil

        do {
            // Use BillService to delete the bill
            let billService = BillService()
            try await billService.deleteBill(
                billId: bill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )


            // Navigate back after successful deletion
            dismiss()

        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}