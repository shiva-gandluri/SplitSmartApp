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
    private var currentBill: Bill {
        // For deleted bills, use passed bill since billManager filters them out
        // For active bills, get latest from billManager to reflect real-time updates
        if bill.isDeleted {
            return bill
        }
        return billManager.bills.first(where: { $0.id == bill.id }) ?? bill
    }

    private var isCreator: Bool {
        let result = authViewModel.user?.uid == currentBill.createdBy
        if let deletedBy = currentBill.deletedBy {
        }
        return result
    }

    private var billTotal: Double {
        currentBill.items.reduce(0) { $0 + $1.price }
    }

    private var creator: BillParticipant? {
        currentBill.participants.first { $0.id == currentBill.createdBy }
    }

    private var payer: BillParticipant? {
        currentBill.participants.first { $0.id == currentBill.paidBy }
    }
    
    var body: some View {

        return ScrollView {
            VStack(spacing: 24) {
                // Debug logging for deletion state
                Color.clear.onAppear {
                    if let deletedBy = currentBill.deletedBy, let deletedAt = currentBill.deletedAt {
                    }
                }

                // Deleted Bill Banner
                if currentBill.isDeleted {
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
                if isCreator && !currentBill.isDeleted {
                    actionButtons
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(currentBill.isDeleted ? "Deleted Bill" : "Bill Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditView) {
            BillEditView(
                bill: currentBill,
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
        VStack(spacing: .spacingMD) {
            HStack(spacing: .spacingMD) {
                Image(systemName: "trash.slash.fill")
                    .font(.h3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text("This bill has been deleted")
                        .font(.h4Dynamic)
                        .foregroundColor(.white)

                    if let deletedByName = currentBill.deletedByDisplayName,
                       let deletedAt = currentBill.deletedAt {
                        Text("Deleted by \(deletedByName) on \(deletedAt.dateValue().formatted(date: .abbreviated, time: .shortened))")
                            .font(.captionDynamic)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()
            }
            .padding(.paddingCard)
            .background(Color.adaptiveAccentRed)
            .cornerRadius(.cornerRadiusMedium)

            Text("This is a read-only view for your records. You cannot edit or restore this bill.")
                .font(.smallDynamic)
                .foregroundColor(.adaptiveTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, .paddingScreen)
    }

    private var headerSection: some View {
        VStack(spacing: .spacingMD) {
            HStack {
                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(currentBill.billName ?? "Bill #\(currentBill.id.prefix(8))")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)

                    Text("Created on \(currentBill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                        .font(.smallDynamic)
                        .foregroundColor(.adaptiveTextSecondary)

                    if currentBill.isDeleted {
                        HStack {
                            Image(systemName: "trash.slash")
                                .foregroundColor(.adaptiveAccentRed)
                            Text("DELETED")
                                .font(.captionDynamic)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveAccentRed)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, .paddingScreen)
        }
    }
    
    private var billOverviewSection: some View {
        VStack(spacing: .spacingMD) {
            // Total Amount
            HStack {
                Text("Total Amount:")
                    .font(.h4Dynamic)
                    .foregroundColor(.adaptiveTextPrimary)
                Spacer()
                Text("$\(billTotal, specifier: "%.2f")")
                    .font(.h3Dynamic)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptiveAccentBlue)
            }

            // Creator Info
            if let creator = creator {
                HStack {
                    Text("Created by:")
                        .font(.smallDynamic)
                        .foregroundColor(.adaptiveTextSecondary)

                    HStack(spacing: .spacingSM) {
                        Circle()
                            .fill(Color.adaptiveAccentBlue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.captionText)
                                    .foregroundColor(.white)
                            )
                        Text(creator.displayName)
                            .font(.bodyDynamic)
                            .fontWeight(.medium)
                            .foregroundColor(.adaptiveTextPrimary)
                    }

                    Spacer()
                }
            }

            // Payer Info
            if let payer = payer {
                HStack {
                    Text("Paid by:")
                        .font(.smallDynamic)
                        .foregroundColor(.adaptiveTextSecondary)

                    HStack(spacing: .spacingSM) {
                        Circle()
                            .fill(Color.adaptiveAccentGreen)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "creditcard.fill")
                                    .font(.captionText)
                                    .foregroundColor(.white)
                            )
                        Text(payer.displayName)
                            .font(.bodyDynamic)
                            .fontWeight(.medium)
                            .foregroundColor(.adaptiveTextPrimary)
                    }

                    Spacer()
                }
            }
        }
        .padding(.paddingCard)
        .background(Color.adaptiveDepth1)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.adaptiveAccentBlue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, .paddingScreen)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: .spacingMD) {
            Text("Who Owes What")
                .font(.h4Dynamic)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.horizontal, .paddingScreen)
            
            let owedAmounts = BillCalculator.calculateOwedAmounts(bill: currentBill)
            
            if owedAmounts.isEmpty || owedAmounts.allSatisfy({ $0.value <= 0.01 }) {
                // All settled up
                VStack(spacing: .spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.adaptiveAccentGreen)
                        .font(.h3)
                    Text("All settled up!")
                        .font(.bodyDynamic)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveAccentGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.paddingCard)
                .background(Color.adaptiveAccentGreen.opacity(0.1))
                .cornerRadius(.cornerRadiusMedium)
                .padding(.horizontal, .paddingScreen)
            } else {
                // Show debts
                ForEach(owedAmounts.sorted(by: { $0.key < $1.key }), id: \.key) { participantId, amount in
                    if let debtor = currentBill.participants.first(where: { $0.id == participantId }),
                       let payer = payer,
                       amount > 0.01 {
                        
                        HStack {
                            // Debtor
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.adaptiveAccentRed)
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
                                    .fill(Color.adaptiveAccentGreen)
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
                                .foregroundColor(.adaptiveAccentRed)
                        }
                        .padding(.paddingCard)
                        .background(Color.adaptiveDepth1)
                        .cornerRadius(.cornerRadiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                .stroke(Color.adaptiveAccentRed.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, .paddingScreen)
                    }
                }
            }
        }
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: .spacingMD) {
            Text("Items (\(currentBill.items.count))")
                .font(.h4Dynamic)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.horizontal, .paddingScreen)

            LazyVStack(spacing: .spacingSM) {
                ForEach(currentBill.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text(item.name)
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)

                            Text("Split among \(item.participantIDs.count) people")
                                .font(.captionDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                        }

                        Spacer()

                        Text("$\(item.price, specifier: "%.2f")")
                            .font(.bodyDynamic)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveTextPrimary)
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth1)
                    .cornerRadius(.cornerRadiusSmall)
                }
            }
            .padding(.horizontal, .paddingScreen)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: .spacingMD) {
            // Edit Button
            Button(action: {
                editSession.loadBill(currentBill)
                showingEditView = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Bill")
                        .font(.buttonText)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.adaptiveAccentBlue)
                .frame(maxWidth: .infinity)
                .padding(.spacingMD)
                .background(Color.adaptiveAccentBlue.opacity(0.1))
                .cornerRadius(.cornerRadiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .stroke(Color.adaptiveAccentBlue.opacity(0.3), lineWidth: 1)
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
                        .font(.buttonText)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.spacingMD)
                .background(isDeleting ? Color.gray : Color.adaptiveAccentRed)
                .cornerRadius(.cornerRadiusMedium)
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, .paddingScreen)
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
                billId: currentBill.id,
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