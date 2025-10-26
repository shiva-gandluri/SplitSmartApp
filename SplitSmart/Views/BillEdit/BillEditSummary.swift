//
//  BillEditSummary.swift
//  SplitSmart
//
//  Bill edit summary screen
//  Updates existing bill instead of creating new one
//

import SwiftUI

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
                    .font(.bodyText)
                    .foregroundColor(.adaptiveTextPrimary)
                    .padding(.spacingMD)
                    .background(Color.adaptiveDepth1)
                    .cornerRadius(.cornerRadiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                            .stroke(Color.adaptiveTextPrimary.opacity(0.2), lineWidth: 1)
                    )
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
                                .foregroundColor(.adaptiveAccentBlue)
                        } else {
                            Text("Bill paid by Unknown")
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveAccentRed)
                        }
                        Spacer()
                    }

                    HStack {
                        Text("Total amount:")
                        Spacer()
                        Text("$\(session.totalAmount, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.adaptiveAccentBlue)

                    HStack {
                        Text("Date & Time:")
                        Spacer()
                        Text("\(Date().formatted(date: .abbreviated, time: .shortened))")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.adaptiveAccentBlue)
                }
                .padding()
                .background(Color.adaptiveAccentBlue.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.adaptiveAccentBlue.opacity(0.3), lineWidth: 1)
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
                            if let debtor = session.participants.first(where: { $0.id == participantID }),
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
                                            .foregroundColor(.adaptiveAccentRed)
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
                                        .stroke(Color.adaptiveAccentRed.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }

                        // Show "No debts" message if everyone paid their share
                        if session.individualDebts.allSatisfy({ $0.value <= 0.01 }) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.adaptiveAccentGreen)
                                    .font(.title2)
                                Text("Everyone paid their share!")
                                    .fontWeight(.medium)
                                    .foregroundColor(.adaptiveAccentGreen)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.adaptiveAccentGreen.opacity(0.1))
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
                            .background(Color.adaptiveDepth1.opacity(0.5))

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
                            .background(Color.adaptiveDepth1.opacity(0.5))
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
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isUpdating || !session.isReadyForBillCreation)
                .padding(.horizontal)

                // Show error if bill update fails
                if let error = updateError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.adaptiveAccentRed)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentRed)
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
            updateError = session.billCreationErrorMessage ?? "Session is not ready for bill update"
            showingError = true
            return
        }

        isUpdating = true
        updateError = nil

        do {

            // Convert session data back to BillItem and BillParticipant format
            let updatedItems = session.assignedItems.map { assignedItem in
                BillItem(
                    name: assignedItem.name,
                    price: assignedItem.price,
                    participantIDs: Array(assignedItem.assignedToParticipants)  // Use Firebase UIDs directly
                )
            }

            let paidByParticipantId: String = {
                if let paidByID = session.paidByParticipantID {

                    if paidByID == authViewModel.user?.uid { // Current user
                        return authViewModel.user?.uid ?? ""
                    } else {
                        // Use the Firebase UID directly since UIParticipant.id is now Firebase UID

                        // Verify the participant exists in bill participants
                        if bill.participants.contains(where: { $0.id == paidByID }) {
                            return paidByID
                        } else {
                            return authViewModel.user?.uid ?? ""
                        }
                    }
                } else {
                    let originalPayer = bill.paidBy
                    return originalPayer
                }
            }()

            // Update bill using BillService
            try await billService.updateBill(
                billId: bill.id,
                billName: session.billName.isEmpty ? defaultBillName : session.billName,
                items: updatedItems,
                participants: bill.participants, // Keep same participants
                paidByParticipantId: paidByParticipantId,
                currentUserId: authViewModel.user?.uid ?? "",
                currentUserEmail: authViewModel.user?.email ?? "",
                billManager: billManager
            )


            // 🔧 CRITICAL DEBUG: Final verification of update results

            // Force refresh BillManager to ensure UI updates
            await billManager.refreshBills()

            // Call the completion handler
            onDone()

        } catch {
            updateError = error.localizedDescription
            showingError = true
        }

        isUpdating = false
    }
}
