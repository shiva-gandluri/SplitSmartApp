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
                                    .foregroundColor(.adaptiveAccentRed)
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
                                                    .foregroundColor(.adaptiveAccentBlue)
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
                                        .stroke(Color.adaptiveAccentBlue, lineWidth: 2)
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
                                    assignedToParticipants: Set<String>(),
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

                                    // Auto-save session after assignment change
                                    session.autoSaveSession()
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
                        .background(Color.adaptiveDepth1)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        let regexTotal = session.regexDetectedItems.reduce(0) { $0.currencyAdd($1.price) }
                        let regexTotalsMatch = abs(regexTotal - session.confirmedTotal) <= 0.01
                        
                        Button(action: {
                            // Regex items are already loaded in assignedItems (see lines 199-212)
                            // Just ensure they're set if somehow empty, but preserve any existing assignments
                            if session.assignedItems.isEmpty {
                                session.assignedItems = session.regexDetectedItems.enumerated().map { index, receiptItem in
                                    UIItem(
                                        id: index + 1,
                                        name: receiptItem.name,
                                        price: receiptItem.price,
                                        assignedTo: nil,
                                        assignedToParticipants: Set<String>(), // Start with no assignments - let user assign manually
                                        confidence: receiptItem.confidence,
                                        originalDetectedName: receiptItem.originalDetectedName,
                                        originalDetectedPrice: receiptItem.originalDetectedPrice
                                    )
                                }
                            }

                            // Auto-save session
                            session.autoSaveSession()

                            // Don't navigate yet - let user assign items manually below
                            // They'll use "Continue to Summary" button when ready
                        }) {
                            HStack {
                                Text("Use These Items")
                                Image(systemName: "checkmark.circle")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(regexTotalsMatch ? Color.adaptiveAccentGreen : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!regexTotalsMatch)
                        .padding(.horizontal)
                        
                        if !regexTotalsMatch {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentRed)
                                Text("Totals do not match.")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentRed)
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

                                    // Auto-save session after assignment change
                                    session.autoSaveSession()
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
                        .background(Color.adaptiveDepth1)
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
                            .background(canContinue ? Color.adaptiveAccentBlue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canContinue)
                        .padding(.horizontal)
                        
                        if !whoePaidSelected {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentRed)
                                Text("Please select who paid this bill.")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentRed)
                            }
                            .padding(.horizontal)
                        } else if !allItemsAssigned {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentOrange)
                                Text("Please assign all items to participants.")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentOrange)
                            }
                            .padding(.horizontal)
                        } else if !totalComplete {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentRed)
                                Text("Assignment total doesn't match bill total.")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentRed)
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
                        
                        await session.processWithBothApproaches(
                            confirmedTax: session.confirmedTax,
                            confirmedTip: session.confirmedTip,
                            confirmedTotal: session.confirmedTotal,
                            expectedItemCount: session.expectedItemCount
                        )
                    } else {
                    }
                }
            }
        }
        .background(Color.adaptiveDepth0.ignoresSafeArea())
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

        Task {
            var rejectedContacts: [String] = []
            var firstNeedsNetworkContact: (name: String, email: String)? = nil

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
                    // Successfully added
                } else if result.needsContact {
                    // User is registered but not in network - save the first one to show modal
                    if firstNeedsNetworkContact == nil, let email = email {
                        firstNeedsNetworkContact = (contactName, email)
                    }
                } else {
                    // User not registered at all
                    rejectedContacts.append(contactName)
                }
            }

            await MainActor.run {
                // Priority: Show network addition modal if we found registered users not in network
                if let needsNetwork = firstNeedsNetworkContact {
                    pendingContactEmail = needsNetwork.email
                    pendingContactName = needsNetwork.name
                    showNewContactModal = true
                } else if !rejectedContacts.isEmpty {
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
        Task {
            // Use proper validation even for network contacts to ensure strict security
            let result = await session.addParticipantWithValidation(
                name: contact.displayName,
                email: contact.email,
                phoneNumber: contact.phoneNumber,
                authViewModel: authViewModel,
                contactsManager: contactsManager
            )

            await MainActor.run {
                if result.participant != nil {
                    newParticipantName = ""
                    successMessage = "Contact saved and added to current bill!"
                    showSuccessAlert = true

                    // Auto-save session after participant change
                    session.autoSaveSession()
                } else if result.needsContact {
                    // User is registered but not in your network - show modal to add them
                    pendingContactEmail = contact.email
                    pendingContactName = contact.displayName
                    showNewContactModal = true
                } else if let error = result.error {
                    validationError = error
                    showValidationAlert = true
                }
            }
        }
    }
    
    private func handleExistingContactSelected(_ contact: TransactionContact) {
        print("🔵 [AssignScreen] handleExistingContactSelected called: \(contact.displayName) (\(contact.email))")
        Task {
            // Use proper validation for existing contacts to ensure strict security
            let result = await session.addParticipantWithValidation(
                name: contact.displayName,
                email: contact.email,
                phoneNumber: contact.phoneNumber,
                authViewModel: authViewModel,
                contactsManager: contactsManager
            )

            print("🔵 [AssignScreen] Validation result - participant: \(result.participant?.name ?? "nil"), error: \(result.error ?? "nil"), needsContact: \(result.needsContact)")

            await MainActor.run {
                if result.participant != nil {
                    print("✅ [AssignScreen] Participant added successfully")
                    newParticipantName = ""

                    // Auto-save session after participant change
                    session.autoSaveSession()
                } else if result.needsContact {
                    // User is registered but not in your network - show modal to add them
                    print("📝 [AssignScreen] Showing NewContactModal - needsContact=true")
                    pendingContactEmail = contact.email
                    pendingContactName = contact.displayName
                    showNewContactModal = true
                } else if let error = result.error {
                    print("❌ [AssignScreen] Showing error alert: \(error)")
                    validationError = error
                    showValidationAlert = true
                }
            }
        }
    }
    
    private func handleNewContactSubmit(_ searchText: String) {
        print("🟢 [AssignScreen] handleNewContactSubmit called: \(searchText)")
        // Process new contact like the old handleAddParticipant but with the search text
        newParticipantName = searchText
        handleAddParticipant()
    }
    
    private func handleAddParticipant() {
        let trimmedName = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🟡 [AssignScreen] handleAddParticipant called: \(trimmedName)")

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
                        if let existingContact = contactsManager.transactionContacts.first(where: { 
                            $0.email.lowercased() == emailValidation.sanitized?.lowercased() 
                        }) {
                            // Use the saved display name from transaction contacts
                            participantName = existingContact.displayName
                        } else {
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

                print("🟡 [AssignScreen] handleAddParticipant validation result - participant: \(result.participant?.name ?? "nil"), error: \(result.error ?? "nil"), needsContact: \(result.needsContact)")

                await MainActor.run {
                    if result.participant != nil {
                        print("✅ [AssignScreen] handleAddParticipant - Participant added successfully")
                        newParticipantName = ""
                        showAddParticipantOptions = false

                        // Auto-save session after participant change
                        session.autoSaveSession()
                    } else if result.needsContact {
                        // Show new contact modal for unregistered email
                        print("📝 [AssignScreen] handleAddParticipant - Showing NewContactModal - needsContact=true")
                        pendingContactEmail = email ?? ""
                        pendingContactName = participantName
                        showNewContactModal = true
                        showAddParticipantOptions = false
                    } else {
                        print("❌ [AssignScreen] handleAddParticipant - Showing error alert: \(result.error ?? "Unknown error")")
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