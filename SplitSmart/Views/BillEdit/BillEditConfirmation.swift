//
//  BillEditConfirmation.swift
//  SplitSmart
//
//  Bill edit confirmation view (replaces scan screen for editing)
//  Allows verification and adjustment of bill details before assignment
//

import SwiftUI

struct BillEditConfirmationView: View {
    let bill: Bill
    @ObservedObject var session: BillSplitSession
    let onContinue: () -> Void
    @Environment(\.presentationMode) var presentationMode

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
                // Header with back button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .regular))
                        }
                        .foregroundColor(.adaptiveAccentBlue)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

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

                // Bill Details Section
                VStack(spacing: 0) {
                    // Subtotal (calculated, read-only)
                    HStack {
                        Text("Subtotal")
                            .font(.body)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        Text("$\(calculatedSubtotal, specifier: "%.2f")")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveTextPrimary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)

                    // Divider
                    Rectangle()
                        .fill(Color.adaptiveTextTertiary.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal)

                    // Number of Items
                    HStack {
                        Text("Number of Items")
                            .font(.body)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        TextField("\(session.scannedItems.count)", text: $editedItemCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveTextPrimary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)

                    // Divider
                    Rectangle()
                        .fill(Color.adaptiveTextTertiary.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal)

                    // Tax Amount
                    HStack {
                        Text("Tax Amount")
                            .font(.body)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("0.00", text: $editedTax)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)

                    // Divider
                    Rectangle()
                        .fill(Color.adaptiveTextTertiary.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal)

                    // Tip Amount
                    HStack {
                        Text("Tip Amount")
                            .font(.body)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("0.00", text: $editedTip)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)

                    // Divider (stronger for total section)
                    Rectangle()
                        .fill(Color.adaptiveTextTertiary.opacity(0.4))
                        .frame(height: 2)
                        .padding(.horizontal)

                    // Total Amount
                    HStack {
                        Text("Total Amount")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("\(bill.totalAmount, specifier: "%.2f")", text: $editedTotal)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .padding(.horizontal)

                // Validation message
                if !totalsMatch {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.adaptiveAccentOrange)
                        Text("Totals don't match. Please verify the amounts above.")
                            .font(.subheadline)
                            .foregroundColor(.adaptiveAccentOrange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveAccentOrange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.adaptiveAccentGreen)
                        Text("Totals match!")
                            .font(.subheadline)
                            .foregroundColor(.adaptiveAccentGreen)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveAccentGreen.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

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
                    .background(totalsMatch ? Color.adaptiveAccentBlue : Color.gray)
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
