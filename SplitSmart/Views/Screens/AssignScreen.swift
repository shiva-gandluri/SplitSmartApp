import SwiftUI
import Contacts
import ContactsUI

/**
 * Assignment Screen - Bill Item Assignment Interface
 * 
 * Complex interface for assigning receipt items to participants using dual detection approaches.
 * 
 * Features:
 * - Dual processing: Regex pattern matching + Apple Intelligence
 * - Dynamic participant management with contacts integration
 * - Real-time validation and error handling
 * - Per-item participant assignment interface
 * - Comprehensive assignment summary with progress tracking
 * 
 * Architecture: MVVM with ObservableObject integration for session management
 * Processing: Async dual-approach item detection with confidence scoring
 */

struct UIAssignScreen: View {
    @ObservedObject var session: BillSplitSession
    @ObservedObject var contactsManager: ContactsManager
    let onContinue: () -> Void
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var newParticipantName = ""
    @State private var showContactPicker = false
    @State private var showAddParticipantOptions = false
    @State private var showingImagePopup = false
    @State private var validationError: String? = nil
    @State private var showValidationAlert = false
    @State private var successMessage: String? = nil
    @State private var showSuccessAlert = false
    @State private var showNewContactModal = false
    @State private var pendingContactEmail = ""
    @State private var pendingContactName = ""
    @StateObject private var contactsPermissionManager = ContactsPermissionManager()
    
    // Check if totals match within reasonable tolerance
    private var totalsMatch: Bool {
        guard let identifiedTotal = session.identifiedTotal else { return true }
        return abs(session.totalAmount - identifiedTotal) <= 0.01
    }
    
    // Check if Continue button should be enabled
    private var canContinue: Bool {
        return !session.assignedItems.isEmpty && totalsMatch
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with image preview
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assign Items")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Drag items to assign them to participants")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Who Paid Selection (Mandatory)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Who paid this bill?")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                            }
                            
                            Menu {
                                ForEach(session.participants) { participant in
                                    Button(action: {
                                        session.paidByParticipantID = participant.id
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(participant.color)
                                                .frame(width: 16, height: 16)
                                            Text(participant.name)
                                            if session.paidByParticipantID == participant.id {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let paidByID = session.paidByParticipantID,
                                       let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {
                                        Circle()
                                            .fill(paidByParticipant.color)
                                            .frame(width: 20, height: 20)
                                        Text(paidByParticipant.name)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Select who paid")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 12)
                    }
                    
                    Spacer()
                    
                    // Image preview thumbnail
                    if let image = session.capturedReceiptImage {
                        Button(action: {
                            showingImagePopup = true
                        }) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                // Modern Search Interface for Adding Participants
                VStack(alignment: .leading, spacing: 12) {
                    ParticipantSearchView(
                        searchText: $newParticipantName,
                        transactionContacts: contactsManager.transactionContacts,
                        onContactSelected: { contact in
                            handleExistingContactSelected(contact)
                        },
                        onNewContactSubmit: { searchText in
                            handleNewContactSubmit(searchText)
                        },
                        onCancel: {
                            // No cancel button anymore, but keep callback for compatibility
                        }
                    )
                    .padding(.horizontal)
                    
                    // Participants chips with delete functionality
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(session.participants) { participant in
                            ParticipantChip(
                                participant: participant,
                                canDelete: participant.name != "You", // Can't delete yourself
                                onDelete: {
                                    session.removeParticipant(participant)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Regex Approach Section
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt Items (based on Regex)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Mathematical approach using regex patterns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if session.regexDetectedItems.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Processing with regex approach...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal)
                    } else {
                        // Convert regex items to assignedItems if not already done
                        if session.assignedItems.isEmpty {
                            let _ = session.assignedItems = session.regexDetectedItems.enumerated().map { index, receiptItem in
                                UIItem(
                                    id: index + 1,
                                    name: receiptItem.name,
                                    price: receiptItem.price,
                                    assignedTo: nil,
                                    assignedToParticipants: Set<Int>(),
                                    confidence: receiptItem.confidence,
                                    originalDetectedName: receiptItem.originalDetectedName,
                                    originalDetectedPrice: receiptItem.originalDetectedPrice
                                )
                            }
                        }
                        
                        // New Per-Item Participant Assignment Interface for Regex
                        ForEach(session.assignedItems.indices, id: \.self) { index in
                            ItemRowWithParticipants(
                                item: $session.assignedItems[index],
                                participants: session.participants,
                                onItemUpdate: { updatedItem in
                                    session.updateItemAssignments(updatedItem)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Regex Totals Section
                if !session.regexDetectedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Regex Totals")
                            .font(.body)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Identified Total")
                                    .font(.body)
                                Spacer()
                                Text(String(format: "$%.2f", session.confirmedTotal))
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Calculated Total")
                                    .font(.body)
                                Spacer()
                                let regexTotal = session.regexDetectedItems.reduce(0) { $0.currencyAdd($1.price) }
                                Text(String(format: "$%.2f", regexTotal))
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(abs(regexTotal - session.confirmedTotal) > 0.01 ? .red : .primary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        let regexTotal = session.regexDetectedItems.reduce(0) { $0.currencyAdd($1.price) }
                        let regexTotalsMatch = abs(regexTotal - session.confirmedTotal) <= 0.01
                        
                        Button(action: {
                            // Set regex items as the active assignment with all participants assigned
                            session.assignedItems = session.regexDetectedItems.enumerated().map { index, receiptItem in
                                UIItem(
                                    id: index + 1,
                                    name: receiptItem.name,
                                    price: receiptItem.price,
                                    assignedTo: nil,
                                    assignedToParticipants: Set(session.participants.map { $0.id }), // Assign to all participants
                                    confidence: receiptItem.confidence,
                                    originalDetectedName: receiptItem.originalDetectedName,
                                    originalDetectedPrice: receiptItem.originalDetectedPrice
                                )
                            }
                            splitSharedItems()
                            onContinue()
                        }) {
                            HStack {
                                Text("Continue with Regex Results")
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(regexTotalsMatch ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!regexTotalsMatch)
                        .padding(.horizontal)
                        
                        if !regexTotalsMatch {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Totals do not match.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // LLM Approach Section
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt Items (based on Apple Intelligence)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("AI-powered approach using Apple's Natural Language framework")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if session.llmDetectedItems.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Processing with Apple Intelligence...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal)
                    } else {
                        // New Per-Item Participant Assignment Interface
                        ForEach(session.assignedItems.indices, id: \.self) { index in
                            ItemRowWithParticipants(
                                item: $session.assignedItems[index],
                                participants: session.participants,
                                onItemUpdate: { updatedItem in
                                    session.updateItemAssignments(updatedItem)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Assignment Summary and Continue Section
                if !session.assignedItems.isEmpty {
                    // Calculate assignment progress values
                    let totalItems = session.assignedItems.count
                    let assignedItems = session.assignedItems.filter { !$0.assignedToParticipants.isEmpty }.count
                    let assignedTotal = session.assignedItems.reduce(0.0) { total, item in
                        return total + (item.assignedToParticipants.isEmpty ? 0 : item.price)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assignment Summary")
                            .font(.body)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Receipt Total")
                                    .font(.body)
                                Spacer()
                                Text(String(format: "$%.2f", session.confirmedTotal))
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Assigned Total")
                                    .font(.body)
                                Spacer()
                                Text(String(format: "$%.2f", assignedTotal))
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(abs(assignedTotal - session.confirmedTotal) > 0.01 ? .orange : .green)
                            }
                            
                            HStack {
                                Text("Items Assigned")
                                    .font(.body)
                                Spacer()
                                Text("\(assignedItems) of \(totalItems)")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(assignedItems == totalItems ? .green : .orange)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        let allItemsAssigned = session.assignedItems.allSatisfy { !$0.assignedToParticipants.isEmpty }
                        let totalComplete = abs(assignedTotal - session.confirmedTotal) <= 0.01
                        let whoePaidSelected = session.paidByParticipantID != nil
                        let canContinue = session.isReadyForBillCreation && totalComplete
                        
                        Button(action: {
                            onContinue()
                        }) {
                            HStack {
                                Text("Continue to Summary")
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canContinue ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canContinue)
                        .padding(.horizontal)
                        
                        if !whoePaidSelected {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Please select who paid this bill.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        } else if !allItemsAssigned {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Please assign all items to participants.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                        } else if !totalComplete {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Assignment total doesn't match bill total.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top)
        }
        .onAppear {
            // Check if this is edit mode (assignments already exist) or new bill mode
            if !session.assignedItems.isEmpty && !session.regexDetectedItems.isEmpty && !session.llmDetectedItems.isEmpty {
                // Edit mode: Items are already populated, don't reprocess
                print("✅ UIAssignScreen: Edit mode detected, skipping processing (items already assigned)")
                print("   - assignedItems: \(session.assignedItems.count)")
                print("   - regexDetectedItems: \(session.regexDetectedItems.count)")
                print("   - llmDetectedItems: \(session.llmDetectedItems.count)")
            } else {
                // New bill mode: Trigger dual processing when screen appears to ensure fresh results
                // Clear any existing results first to prevent showing stale data
                Task {
                    await MainActor.run {
                        session.regexDetectedItems.removeAll()
                        session.llmDetectedItems.removeAll()
                    }
                    
                    // Only process if we have the necessary data from the current session
                    if session.confirmedTotal > 0 && !session.rawReceiptText.isEmpty && session.expectedItemCount > 0 {
                        print("🔄 UIAssignScreen: Triggering dual processing for new bill")
                        print("   - confirmedTotal: \(session.confirmedTotal)")
                        print("   - expectedItemCount: \(session.expectedItemCount)")
                        print("   - rawReceiptText length: \(session.rawReceiptText.count)")
                        
                        await session.processWithBothApproaches(
                            confirmedTax: session.confirmedTax,
                            confirmedTip: session.confirmedTip,
                            confirmedTotal: session.confirmedTotal,
                            expectedItemCount: session.expectedItemCount
                        )
                    } else {
                        print("❌ UIAssignScreen: Not processing - missing required data")
                        print("   - confirmedTotal: \(session.confirmedTotal)")
                        print("   - expectedItemCount: \(session.expectedItemCount)")
                        print("   - rawReceiptText isEmpty: \(session.rawReceiptText.isEmpty)")
                    }
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker(isPresented: $showContactPicker) { contacts in
                handleContactsSelected(contacts)
            }
        }
        .sheet(isPresented: $showNewContactModal) {
            NewContactModal(
                contactsManager: contactsManager,
                authViewModel: authViewModel,
                prefilledEmail: pendingContactEmail
            ) { savedContact in
                handleContactSaved(savedContact)
            }
        }
        .fullScreenCover(isPresented: $showingImagePopup) {
            if let image = session.capturedReceiptImage {
                ImagePopupView(image: image) {
                    showingImagePopup = false
                }
            }
        }
        .alert("Permission Required", isPresented: $contactsPermissionManager.showPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text(contactsPermissionManager.permissionMessage)
        }
        .alert("❌ Error", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationError ?? "An error occurred.")
        }
        .alert("✅ Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage ?? "Operation completed successfully.")
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleChooseFromContacts() {
        // Check contacts permission before proceeding
        switch contactsPermissionManager.contactsPermissionStatus {
        case .authorized:
            showAddParticipantOptions = false
            showContactPicker = true
        case .notDetermined:
            contactsPermissionManager.requestContactsPermission()
            // Wait for permission result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if contactsPermissionManager.contactsPermissionStatus == .authorized {
                    showAddParticipantOptions = false
                    showContactPicker = true
                }
            }
        case .denied, .restricted, .limited:
            contactsPermissionManager.showPermissionAlert = true
        @unknown default:
            contactsPermissionManager.showPermissionAlert = true
        }
    }
    
    // Helper function to convert ReceiptItems to UIItems
    private func convertReceiptItemsToUIItems(_ receiptItems: [ReceiptItem]) -> [UIItem] {
        return receiptItems.enumerated().map { index, receiptItem in
            UIItem(
                id: index + 1,
                name: receiptItem.name,
                price: receiptItem.price,
                assignedTo: nil,
                confidence: receiptItem.confidence,
                originalDetectedName: receiptItem.originalDetectedName,
                originalDetectedPrice: receiptItem.originalDetectedPrice
            )
        }
    }
    
    private func handleContactsSelected(_ contacts: [CNContact]) {
        print("📱 Selected \(contacts.count) contacts from picker")
        
        Task {
            var rejectedContacts: [String] = []
            
            for contact in contacts {
                let contactName = contact.displayName
                let email = contact.primaryEmail
                let phoneNumber = contact.primaryPhoneNumber
                
                // Use validation method
                let result = await session.addParticipantWithValidation(
                    name: contactName,
                    email: email,
                    phoneNumber: phoneNumber,
                    authViewModel: authViewModel,
                    contactsManager: contactsManager
                )
                
                if result.participant != nil {
                    print("✅ Added validated participant: \(contactName)")
                } else {
                    print("⚠️ Participant \(contactName) rejected: \(result.error ?? "Unknown error")")
                    rejectedContacts.append(contactName)
                }
            }
            
            await MainActor.run {
                if !rejectedContacts.isEmpty {
                    validationError = "The following contacts are not registered with SplitSmart and cannot be added:\n\n" + rejectedContacts.joined(separator: "\n")
                    showValidationAlert = true
                }
                
                showContactPicker = false
                showAddParticipantOptions = false
            }
        }
    }
    
    private func deleteParticipant(_ participant: UIParticipant) {
        // Use session to remove participant (handles item unassignment automatically)
        session.removeParticipant(participant)
    }
    
    private func handleContactSaved(_ contact: TransactionContact) {
        // Check if trying to add yourself
        if contact.displayName.lowercased() == "you" {
            validationError = "You are already in this bill"
            showValidationAlert = true
            return
        }
        
        // Check if participant already exists
        if session.participants.contains(where: { $0.name.lowercased() == contact.displayName.lowercased() }) {
            validationError = "\(contact.displayName) is already in this bill"
            showValidationAlert = true
            return
        }
        
        // After saving contact, directly add them to the current bill without re-validation
        // since we know they're now in our network
        
        let newId = (session.participants.map { $0.id }.max() ?? 0) + 1
        let colorIndex = session.participants.count % session.colors.count
        
        let newParticipant = UIParticipant(
            id: newId,
            name: contact.displayName,
            color: session.colors[colorIndex]
        )
        
        session.participants.append(newParticipant)
        
        print("✅ Added new network contact as participant: \(contact.displayName)")
        newParticipantName = ""
        
        // Show success message
        successMessage = "Contact saved and added to current bill!"
        showSuccessAlert = true
    }
    
    private func handleExistingContactSelected(_ contact: TransactionContact) {
        Task {
            // SECURITY: Check if trying to add yourself by comparing emails
            let currentUserEmail = await MainActor.run { authViewModel.user?.email }
            if let currentUserEmail = currentUserEmail,
               contact.email.lowercased() == currentUserEmail.lowercased() {
                await MainActor.run {
                    validationError = "You cannot add yourself to the bill"
                    showValidationAlert = true
                }
                return
            }
            
            await MainActor.run {
                // Check if participant already exists
                if session.participants.contains(where: { $0.name.lowercased() == contact.displayName.lowercased() }) {
                    validationError = "\(contact.displayName) is already in this bill"
                    showValidationAlert = true
                    return
                }
                
                // Add existing contact to current bill
                let newId = (session.participants.map { $0.id }.max() ?? 0) + 1
                let colorIndex = session.participants.count % session.colors.count
                
                let newParticipant = UIParticipant(
                    id: newId,
                    name: contact.displayName,
                    color: session.colors[colorIndex]
                )
                
                session.participants.append(newParticipant)
                
                print("✅ Added existing contact as participant: \(contact.displayName)")
                newParticipantName = ""
            }
        }
    }
    
    private func handleNewContactSubmit(_ searchText: String) {
        // Process new contact like the old handleAddParticipant but with the search text
        newParticipantName = searchText
        handleAddParticipant()
    }
    
    private func handleAddParticipant() {
        let trimmedName = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedName.isEmpty {
            Task {
                // SECURE: Use proper validation for input detection and sanitization
                var email: String? = nil
                var phoneNumber: String? = nil
                var participantName = trimmedName
                var validationError: String? = nil
                
                // Try email validation first
                if trimmedName.contains("@") {
                    let emailValidation = AuthViewModel.validateEmail(trimmedName)
                    if emailValidation.isValid {
                        email = emailValidation.sanitized
                        
                        // Check if this email is already in user's transaction contacts
                        print("🔍 Checking transaction contacts (count: \(contactsManager.transactionContacts.count)) for email: \(emailValidation.sanitized ?? "")")
                        if let existingContact = contactsManager.transactionContacts.first(where: { 
                            $0.email.lowercased() == emailValidation.sanitized?.lowercased() 
                        }) {
                            // Use the saved display name from transaction contacts
                            participantName = existingContact.displayName
                            print("📋 Found existing contact: \(existingContact.displayName) for email: \(emailValidation.sanitized ?? "")")
                        } else {
                            print("❌ No existing contact found for email: \(emailValidation.sanitized ?? "")")
                            print("📋 Available contacts: \(contactsManager.transactionContacts.map { "\($0.displayName) (\($0.email))" })")
                            // Extract name from email (part before @) as fallback
                            participantName = String(trimmedName.split(separator: "@").first ?? Substring(trimmedName))
                            
                            // Validate the extracted name
                            let nameValidation = AuthViewModel.validateDisplayName(participantName)
                            if nameValidation.isValid {
                                participantName = nameValidation.sanitized!
                            } else {
                                participantName = "User" // Fallback
                            }
                        }
                    } else {
                        validationError = emailValidation.error
                    }
                }
                // Try phone validation if not email
                else {
                    let phoneValidation = AuthViewModel.validatePhoneNumber(trimmedName)
                    if phoneValidation.isValid {
                        phoneNumber = phoneValidation.sanitized
                        // Use phone as name for now, but validate it
                        let nameValidation = AuthViewModel.validateDisplayName(trimmedName)
                        participantName = nameValidation.isValid ? nameValidation.sanitized! : "User"
                    } else {
                        // If neither email nor phone, treat as display name
                        let nameValidation = AuthViewModel.validateDisplayName(trimmedName)
                        if nameValidation.isValid {
                            participantName = nameValidation.sanitized!
                        } else {
                            validationError = nameValidation.error
                        }
                    }
                }
                
                await MainActor.run {
                    if let error = validationError {
                        self.validationError = error
                        showValidationAlert = true
                        return
                    }
                }
                
                let result = await session.addParticipantWithValidation(
                    name: participantName,
                    email: email,
                    phoneNumber: phoneNumber,
                    authViewModel: authViewModel,
                    contactsManager: contactsManager
                )
                
                await MainActor.run {
                    if result.participant != nil {
                        print("✅ Added validated participant manually: \(trimmedName)")
                        newParticipantName = ""
                        showAddParticipantOptions = false
                    } else if result.needsContact {
                        print("📝 Showing contact modal for email: \(email ?? "nil")")
                        // Show new contact modal for unregistered email
                        pendingContactEmail = email ?? ""
                        pendingContactName = participantName
                        showNewContactModal = true
                        showAddParticipantOptions = false
                    } else {
                        self.validationError = result.error ?? "Unable to add participant"
                        showValidationAlert = true
                    }
                }
            }
        }
    }
    
    private func splitSharedItems() {
        for index in session.assignedItems.indices {
            if session.assignedItems[index].assignedTo == nil && 
               (session.assignedItems[index].name.lowercased().contains("tax") || 
                session.assignedItems[index].name.lowercased().contains("tip")) {
                session.assignedItems[index].name += " (Split equally)"
            }
        }
    }
}