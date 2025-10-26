import SwiftUI
import FirebaseFirestore

/**
 * Bill Detail Screen - Matches Summary Screen Layout
 *
 * Displays bill details in the same structure as Summary screen
 * with Edit and Delete buttons at the bottom.
 */

struct BillDetailScreen: View {
    let bill: Bill
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var expandedPersonIds: Set<String> = []

    // Computed properties
    private var currentBill: Bill {
        if bill.isDeleted {
            return bill
        }
        return billManager.userBills.first(where: { $0.id == bill.id }) ?? bill
    }

    private var isCreator: Bool {
        authViewModel.user?.uid == currentBill.createdBy
    }

    private var billTotal: Double {
        currentBill.items.reduce(0) { $0 + $1.price }
    }

    private var payer: BillParticipant? {
        currentBill.participants.first { $0.id == currentBill.paidBy }
    }

    // Convert Bill to breakdown format for display
    private var breakdownSummaries: [PersonBreakdown] {
        var breakdowns: [PersonBreakdown] = []

        for participant in currentBill.participants {
            let participantItems = currentBill.items.filter { item in
                item.participantIDs.contains(participant.id)
            }.map { item in
                let splitCount = item.participantIDs.count
                let splitPrice = item.price / Double(splitCount)
                return BreakdownItem(name: item.name, price: splitPrice)
            }

            if !participantItems.isEmpty {
                breakdowns.append(PersonBreakdown(
                    id: participant.id,
                    name: participant.displayName,
                    items: participantItems,
                    photoURL: participant.photoURL
                ))
            }
        }

        return breakdowns
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Deleted Bill Banner (if applicable)
                if currentBill.isDeleted {
                    deletedBillBanner
                        .padding(.bottom, .spacingLG)
                }

                // SECTION 1: Bill Info (white background)
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Bill Details")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.paddingScreen)

                    // Bill info
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        HStack {
                            Text("Bill name")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text(currentBill.billName ?? "Unnamed Bill")
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)
                        }

                        HStack {
                            Text("Bill paid by")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            paidBySection
                        }

                        HStack {
                            Text("Total amount")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text("$\(billTotal, specifier: "%.2f")")
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)
                        }

                        HStack {
                            Text("Date & Time")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text("\(currentBill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                    }
                    .padding(.paddingScreen)
                }
                .background(Color.adaptiveDepth0)

                // SECTION 2: Detailed breakdown with collapsible person cards (light gray background)
                detailedBreakdownSection

                // SECTION 3: Action Buttons (only for creators of active bills)
                if isCreator && !currentBill.isDeleted {
                    actionButtonsSection
                        .background(Color.adaptiveDepth0)
                }
            }
        }
        .background(Color.adaptiveDepth0)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToEdit) {
            BillEditFlow(
                bill: currentBill,
                authViewModel: authViewModel,
                billManager: billManager,
                contactsManager: contactsManager
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
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text("This bill has been deleted")
                        .font(.bodyDynamic)
                        .fontWeight(.semibold)
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

            Text("This is a read-only view for your records.")
                .font(.captionDynamic)
                .foregroundColor(.adaptiveTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, .paddingScreen)
    }

    @ViewBuilder
    private var paidBySection: some View {
        if let payer = payer {
            HStack(spacing: .spacingSM) {
                // Profile picture or fallback avatar
                if let photoURLString = payer.photoURL, let photoURL = URL(string: photoURLString) {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.adaptiveTextSecondary.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.adaptiveTextSecondary)
                                    .font(.captionText)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.adaptiveTextSecondary.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.adaptiveTextSecondary)
                                .font(.captionText)
                        )
                }

                Text(payer.displayName)
                    .font(.bodyDynamic)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveTextPrimary)
            }
        } else {
            Text("Unknown")
                .font(.bodyDynamic)
                .fontWeight(.medium)
                .foregroundColor(.adaptiveAccentRed)
        }
    }

    @ViewBuilder
    private var detailedBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Detailed breakdown")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.paddingScreen)
                .padding(.bottom, .spacingSM)

            ForEach(breakdownSummaries) { person in
                collapsiblePersonCard(for: person)
            }

            // Bottom padding for the section
            Spacer()
                .frame(height: .spacingMD)
        }
    }

    @ViewBuilder
    private func collapsiblePersonCard(for person: PersonBreakdown) -> some View {
        let isExpanded = expandedPersonIds.contains(person.id)
        let totalOwed = person.items.reduce(0.0) { $0 + $1.price }

        VStack(spacing: 0) {
            // Card header with person name, amount, and chevron
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedPersonIds.remove(person.id)
                    } else {
                        expandedPersonIds.insert(person.id)
                    }
                }
            }) {
                HStack(spacing: .spacingMD) {
                    // Person avatar - profile picture or fallback
                    if let photoURLString = person.photoURL, let photoURL = URL(string: photoURLString) {
                        AsyncImage(url: photoURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.adaptiveTextSecondary.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.adaptiveTextSecondary)
                                        .font(.caption)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.adaptiveTextSecondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.adaptiveTextSecondary)
                                    .font(.caption)
                            )
                    }

                    // Person name with "owes" information
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.adaptiveTextPrimary)

                        // Show who this person owes (if they owe money)
                        if let payer = payer,
                           let owedAmount = BillCalculator.calculateOwedAmounts(bill: currentBill)[person.id],
                           owedAmount > 0.01 {
                            Text("owes \(payer.displayName): $\(owedAmount, specifier: "%.2f")")
                                .font(.system(size: 12))
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }

                    Spacer()

                    // Total amount
                    Text("$\(totalOwed, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.adaptiveTextPrimary)

                    // Chevron icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.adaptiveTextSecondary)
                }
                .padding(.horizontal, .paddingScreen)
                .padding(.vertical, .spacingLG)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content: item list, divider, and subtotal
            if isExpanded {
                VStack(spacing: 0) {
                    // Items
                    ForEach(person.items, id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text("$\(item.price, specifier: "%.2f")")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                        .padding(.horizontal, .paddingScreen)
                        .padding(.vertical, .spacingMD)
                    }

                    // Horizontal line before subtotal
                    Divider()
                        .padding(.horizontal, .paddingScreen)

                    // Subtotal
                    HStack {
                        Text("Subtotal")
                            .font(.bodyDynamic)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        Text("$\(totalOwed, specifier: "%.2f")")
                            .font(.bodyDynamic)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveTextPrimary)
                    }
                    .padding(.paddingScreen)
                }
            }
        }
        .background(Color.adaptiveDepth0)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, .paddingScreen)
        .padding(.bottom, .spacingMD)
    }

    private var actionButtonsSection: some View {
        HStack(spacing: .spacingMD) {
            // Edit Button
            Button("Edit") {
                navigateToEdit = true
            }
            .buttonStyle(PrimaryButtonStyle())

            // Delete Button
            Button {
                showingDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Delete")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .disabled(isDeleting)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Actions

    @MainActor
    private func deleteBill() async {
        isDeleting = true
        deleteError = nil

        do {
            let billService = BillService()
            try await billService.deleteBill(
                billId: currentBill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )

            dismiss()

        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}

// MARK: - Helper Models

struct PersonBreakdown: Identifiable {
    let id: String
    let name: String
    let items: [BreakdownItem]
    let photoURL: String?
}

struct BreakdownItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
}
