//
//  BillEditFlow.swift
//  SplitSmart
//
//  Bill editing flow coordinator
//  Manages the 3-step edit process: confirm -> assign -> summary
//

import SwiftUI

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
            uiParticipants.append(UIParticipant(id: currentUserId, name: "You", color: .blue))
        }

        // Add other participants with Firebase UIDs
        for participant in bill.participants {
            if participant.id != authViewModel.user?.uid {
                uiParticipants.append(UIParticipant(
                    id: participant.id,  // Use Firebase UID directly
                    name: participant.displayName,
                    color: .blue  // Use assignedColor computed property for consistent colors
                ))
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
                assignedToParticipants: Set(billItem.participantIDs),  // Use Firebase UIDs directly
                confidence: .high,
                originalDetectedName: nil,
                originalDetectedPrice: nil
            )
        }

    }
}
