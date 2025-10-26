import SwiftUI
import Contacts
import ContactsUI

// MARK: - Contacts Permission Manager
class ContactsPermissionManager: ObservableObject {
    @Published var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionMessage = ""
    
    init() {
        checkContactsPermission()
    }
    
    func checkContactsPermission() {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.contactsPermissionStatus = granted ? .authorized : .denied
                if !granted {
                    self?.showContactsPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func showContactsPermissionDeniedAlert() {
        permissionMessage = "Contacts access is required to add participants from your contact list. Please enable contacts access in Settings > Privacy & Security > Contacts > SplitSmart."
        showPermissionAlert = true
    }
    
    var canAccessContacts: Bool {
        switch contactsPermissionStatus {
        case .authorized:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
}

// MARK: - Contact Picker Wrapper
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContactSelected: ([CNContact]) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        
        // Configure what properties we want to fetch
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        
        // Allow multiple selection
        picker.predicateForEnablingContact = NSPredicate(value: true)
        picker.predicateForSelectionOfContact = NSPredicate(value: true)
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        // Handle single contact selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected([contact])
            parent.isPresented = false
        }
        
        // Handle multiple contact selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onContactSelected(contacts)
            parent.isPresented = false
        }
        
        // Handle cancellation
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Contact Helper Extensions
extension CNContact {
    var displayName: String {
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        return formatter.string(from: self) ?? "Unknown Contact"
    }
    
    var primaryPhoneNumber: String? {
        return phoneNumbers.first?.value.stringValue
    }
    
    var primaryEmail: String? {
        return emailAddresses.first?.value as String?
    }
}

// MARK: - Participant Search View
struct ParticipantSearchView: View {
    @Binding var searchText: String
    let transactionContacts: [TransactionContact]
    let onContactSelected: (TransactionContact) -> Void
    let onNewContactSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var isSearchFocused = false
    @FocusState private var isTextFieldFocused: Bool
    
    var filteredContacts: [TransactionContact] {
        if searchText.isEmpty {
            return Array(transactionContacts.prefix(5)) // Show top 5 recent contacts
        }
        return transactionContacts.filter { contact in
            contact.displayName.lowercased().contains(searchText.lowercased()) ||
            contact.email.lowercased().contains(searchText.lowercased()) ||
            (contact.phoneNumber?.contains(searchText) ?? false)
        }
    }
    
    var isValidEmailOrPhone: Bool {
        searchText.contains("@") || searchText.allSatisfy { char in
            char.isNumber || char == "+" || char == "-" || char == " " || char == "(" || char == ")"
        }
    }
    
    var body: some View {
        // Compact Search Bar
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("Add Participants", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .focused($isTextFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    if !searchText.isEmpty && filteredContacts.isEmpty && isValidEmailOrPhone {
                        onNewContactSubmit(searchText)
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.spacingMD)
        .background(Color.adaptiveDepth3)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            // Dropdown overlay that appears on top
            VStack {
                if !searchText.isEmpty {
                    VStack(spacing: 0) {
                        if !filteredContacts.isEmpty {
                            // Show top 3 contacts in dropdown
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredContacts.prefix(3))) { contact in
                                    ContactResultRow(contact: contact) {
                                        onContactSelected(contact)
                                    }
                                    .background(Color(.systemBackground))

                                    if contact.id != filteredContacts.prefix(3).last?.id {
                                        Divider()
                                            .padding(.leading, 56) // Align with contact text
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        } else if isValidEmailOrPhone {
                            // New contact option in compact dropdown
                            Button(action: {
                                onNewContactSubmit(searchText)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.adaptiveAccentBlue)
                                        .font(.system(size: 20))
                                        .frame(width: 40, height: 40)
                                        .background(Color.adaptiveAccentBlue.opacity(0.1))
                                        .cornerRadius(20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add \(searchText)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("New contact")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, .paddingScreen)
                    .padding(.top, 60) // Position below search bar
                }
            }
            , alignment: .topLeading
        )
        .zIndex(1000) // Ensure entire component with overlay appears on top
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Contact Result Row
struct ContactResultRow: View {
    let contact: TransactionContact
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.adaptiveAccentBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(contact.displayName.prefix(1).uppercased()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.adaptiveAccentBlue)
                    )
                
                // Contact Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(contact.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Transaction count
                if contact.totalTransactions > 1 {
                    Text("\(contact.totalTransactions)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - New Contact Modal
struct NewContactModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    
    let prefilledEmail: String
    let onContactSaved: (TransactionContact) -> Void
    
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var isLoading = false
    @State private var validationError: String?
    @State private var showErrorAlert = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Icon and description
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.adaptiveAccentBlue.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.adaptiveAccentBlue)
                            )
                        
                        VStack(spacing: 8) {
                            Text("Add to Network")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Save this contact to easily add them to future bills")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 24) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Full Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("*")
                                    .font(.subheadline)
                                    .foregroundColor(.adaptiveAccentRed)
                            }
                            
                            TextField("Enter full name", text: $fullName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.adaptiveDepth3)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                .focused($isNameFieldFocused)
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                        
                        // Email Field (read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                
                                Text(prefilledEmail)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        
                        // Phone Number Field (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter phone number", text: $phoneNumber)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.adaptiveDepth3)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                .keyboardType(.phonePad)
                        }
                        
                        // Error message
                        if let errorMessage = validationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentRed)
                                    .font(.system(size: 14))
                                
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentRed)
                                
                                Spacer()
                            }
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveContact) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(validationError ?? "An error occurred")
        }
    }
    
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveContact() {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneToSave = trimmedPhone.isEmpty ? nil : trimmedPhone
        
        isLoading = true
        validationError = nil
        
        Task {
            do {
                // Validate the transaction contact (now async)
                let validation = await contactsManager.validateNewTransactionContact(
                    displayName: fullName,
                    email: prefilledEmail,
                    phoneNumber: phoneToSave,
                    authViewModel: authViewModel
                )
                
                guard validation.isValid, let contact = validation.contact else {
                    await MainActor.run {
                        isLoading = false
                        validationError = validation.error
                        showErrorAlert = true
                    }
                    return
                }
                
                try await contactsManager.saveTransactionContact(contact)
                
                await MainActor.run {
                    isLoading = false
                    onContactSaved(contact)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    validationError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - UI Components matching React designs exactly
// UIHomeScreen moved to Views/Screens/HomeScreen.swift

// MARK: - Data Models are now in Models/DataModels.swift

// MARK: - Scan Screen
// UIScanScreen is now in Views/ScanView.swift

// MARK: - Assign Screen

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

    // Extract complex menu label into computed property
    @ViewBuilder
    private var paidByMenuLabel: some View {
        HStack {
            if let paidByID = session.paidByParticipantID,
               let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {
                Circle()
                    .fill(paidByParticipant.color)
                    .frame(width: 20, height: 20)
                Text(paidByParticipant.name)
                    .foregroundColor(.adaptiveTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("Select who paid")
                    .foregroundColor(.adaptiveTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundColor(.adaptiveTextSecondary)
                .font(.captionText)
        }
        .padding(14)
        .background(Color.adaptiveDepth3)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // Extract header section
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text("Assign Items")
                .font(.h3Dynamic)
                .foregroundColor(.adaptiveTextPrimary)

            Text("Add participants & Assign items")
                .font(.smallDynamic)
                .foregroundColor(.adaptiveTextSecondary)
        }
    }

    private var whoPaidSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Who paid this bill?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.adaptiveTextPrimary)
                Text("*")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.adaptiveAccentRed)
            }

            Spacer()

            Menu {
                ForEach(session.participants) { participant in
                    Button(action: {
                        session.paidByParticipantID = participant.id
                    }) {
                        HStack {
                            Circle()
                                .fill(participant.color)
                                .frame(width: 14, height: 14)
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
                paidByMenuLabel
            }
            .frame(width: 180)
            .onTapGesture {
                // Debug log when Menu is tapped
                for participant in session.participants {
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                headerWithImagePreview
                participantManagementSection
                regexItemsSection
                llmItemsSection
                assignmentSummarySection
            }
            .padding(.top)
        }
        .onAppear(perform: handleOnAppear)
        .onTapGesture(perform: hideKeyboard)
        .toolbar { keyboardToolbar }
        .contactPickerSheet(
            isPresented: $showContactPicker,
            onContactsSelected: handleContactsSelected
        )
        .newContactModalSheet(
            isPresented: $showNewContactModal,
            contactsManager: contactsManager,
            authViewModel: authViewModel,
            prefilledEmail: pendingContactEmail,
            onContactSaved: handleContactSaved
        )
        .imagePopupCover(
            isPresented: $showingImagePopup,
            image: session.capturedReceiptImage
        )
        .permissionAlert(
            isPresented: $contactsPermissionManager.showPermissionAlert,
            message: contactsPermissionManager.permissionMessage
        )
        .validationAlert(
            isPresented: $showValidationAlert,
            message: validationError
        )
        .successAlert(
            isPresented: $showSuccessAlert,
            message: successMessage
        )
    }

    // MARK: - View Components

    private var headerWithImagePreview: some View {
        HStack(alignment: .top) {
            headerSection
            Spacer()
            if let image = session.capturedReceiptImage {
                receiptThumbnail(image: image)
            }
        }
        .padding(.horizontal, .paddingScreen)
    }

    private func receiptThumbnail(image: UIImage) -> some View {
        Button(action: { showingImagePopup = true }) {
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

    private var participantManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ParticipantSearchView(
                searchText: $newParticipantName,
                transactionContacts: contactsManager.transactionContacts,
                onContactSelected: handleExistingContactSelected,
                onNewContactSubmit: handleNewContactSubmit,
                onCancel: {}
            )
            .padding(.horizontal, .paddingScreen)

            participantChips
        }
    }

    private var participantChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(session.participants) { participant in
                    ParticipantChip(
                        participant: participant,
                        canDelete: participant.name != "You",
                        onDelete: { session.removeParticipant(participant) }
                    )
                }
            }
            .padding(.horizontal, .paddingScreen)
        }
    }

    private var regexItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            regexSectionHeader
            regexItemsList
        }
    }

    private var regexSectionHeader: some View {
        Text("Receipt Items (based on Regex)")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.adaptiveTextPrimary)
            .padding(.horizontal, .paddingScreen)
            .padding(.bottom, 0)
    }

    private var regexItemsList: some View {
        Group {
            if session.regexDetectedItems.isEmpty {
                processingIndicator(message: "Processing with regex approach...")
            } else {
                itemAssignmentList
            }
        }
    }

    private var llmItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            llmSectionHeader
            llmItemsList
        }
    }

    private var llmSectionHeader: some View {
        Text("Receipt Items (based on Apple Intelligence)")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.adaptiveTextPrimary)
            .padding(.horizontal, .paddingScreen)
            .padding(.bottom, 0)
    }

    private var llmItemsList: some View {
        Group {
            if session.llmDetectedItems.isEmpty {
                processingIndicator(message: "Processing with Apple Intelligence...")
            } else {
                itemAssignmentList
            }
        }
    }

    private func processingIndicator(message: String) -> some View {
        VStack(spacing: .spacingMD) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.bodyDynamic)
                .foregroundColor(.adaptiveTextSecondary)
        }
        .padding(.vertical, .spacingLG)
        .padding(.horizontal, .paddingScreen)
    }

    private var itemAssignmentList: some View {
        VStack(spacing: 0) {
            if session.assignedItems.isEmpty {
                let _ = initializeAssignedItems()
            }

            // Items with horizontal dividers
            ForEach(session.assignedItems.indices, id: \.self) { index in
                VStack(spacing: 0) {
                    ItemRowWithParticipants(
                        item: $session.assignedItems[index],
                        participants: session.participants,
                        onItemUpdate: session.updateItemAssignments
                    )
                    .padding(.horizontal, .paddingScreen)
                    .padding(.vertical, 20)

                    // Divider between items (not after last item)
                    if index < session.assignedItems.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }

    private var assignmentSummarySection: some View {
        Group {
            if !session.assignedItems.isEmpty {
                VStack(spacing: 24) {
                    whoPaidSection
                        .padding(.horizontal, .paddingScreen)

                    VStack(spacing: 8) {
                        summaryDetails
                        continueButtonSection
                    }
                }
            }
        }
    }

    private var summaryDetails: some View {
        VStack(alignment: .leading, spacing: .spacingMD) {
            Text("Assignment Summary")
                .font(.bodyDynamic)
                .fontWeight(.medium)
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.horizontal, .paddingScreen)

            summaryRows
        }
    }

    private var summaryRows: some View {
        let totalItems = session.assignedItems.count
        let assignedItems = session.assignedItems.filter { !$0.assignedToParticipants.isEmpty }.count
        let assignedTotal = session.assignedItems.reduce(0.0) { total, item in
            total + (item.assignedToParticipants.isEmpty ? 0 : item.price)
        }

        return VStack(spacing: .spacingSM) {
            summaryRow(label: "Receipt Total", value: String(format: "$%.2f", session.confirmedTotal), valueColor: nil)
            summaryRow(
                label: "Assigned Total",
                value: String(format: "$%.2f", assignedTotal),
                valueColor: abs(assignedTotal - session.confirmedTotal) > 0.01 ? .orange : .green
            )
            summaryRow(
                label: "Items Assigned",
                value: "\(assignedItems) of \(totalItems)",
                valueColor: assignedItems == totalItems ? .green : .orange
            )
        }
        .padding(.paddingCard)
        .background(Color.adaptiveDepth2)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, .paddingScreen)
    }

    private func summaryRow(label: String, value: String, valueColor: Color?) -> some View {
        HStack {
            Text(label)
                .font(.bodyDynamic)
                .foregroundColor(.adaptiveTextPrimary)
            Spacer()
            Text(value)
                .font(.bodyDynamic)
                .fontWeight(.bold)
                .foregroundColor(valueColor ?? .adaptiveTextPrimary)
        }
    }

    private var continueButtonSection: some View {
        let assignedTotal = session.assignedItems.reduce(0.0) { total, item in
            total + (item.assignedToParticipants.isEmpty ? 0 : item.price)
        }
        let allItemsAssigned = session.assignedItems.allSatisfy { !$0.assignedToParticipants.isEmpty }
        let totalComplete = abs(assignedTotal - session.confirmedTotal) <= 0.01
        let whoPaidSelected = session.paidByParticipantID != nil
        let canContinue = session.isReadyForBillCreation && totalComplete

        return VStack(spacing: 8) {
            continueButton(enabled: canContinue)
            validationMessages(
                whoPaidSelected: whoPaidSelected,
                allItemsAssigned: allItemsAssigned,
                totalComplete: totalComplete
            )
        }
    }

    private func continueButton(enabled: Bool) -> some View {
        Button(action: onContinue) {
            HStack {
                Text("Continue to Summary")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!enabled)
        .padding(.horizontal, .paddingScreen)
    }

    private func validationMessages(whoPaidSelected: Bool, allItemsAssigned: Bool, totalComplete: Bool) -> some View {
        Group {
            if !whoPaidSelected {
                validationMessage(icon: "exclamationmark.triangle.fill", text: "Please select who paid this bill.", color: .red)
            } else if !allItemsAssigned {
                validationMessage(icon: "exclamationmark.triangle.fill", text: "Please assign all items to participants.", color: .orange)
            } else if !totalComplete {
                validationMessage(icon: "exclamationmark.triangle.fill", text: "Assignment total doesn't match bill total.", color: .red)
            }
        }
    }

    private func validationMessage(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.captionDynamic)
                .foregroundColor(color)
        }
        .padding(.horizontal, .paddingScreen)
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done", action: hideKeyboard)
        }
    }

    // MARK: - Helper Methods

    private func initializeAssignedItems() {
        session.assignedItems = session.regexDetectedItems.enumerated().map { index, receiptItem in
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

    private func handleOnAppear() {
        Task {
            if session.participants.isEmpty {
                await session.initializeWithCurrentUser(authViewModel: authViewModel)
            } else {
                let hasYouParticipant = session.participants.contains { $0.name == "You" }
                if !hasYouParticipant {
                    await session.initializeWithCurrentUser(authViewModel: authViewModel)
                }
            }

            if !session.assignedItems.isEmpty && !session.regexDetectedItems.isEmpty && !session.llmDetectedItems.isEmpty {
                // Edit mode: Items already populated
            } else {
                await MainActor.run {
                    session.regexDetectedItems.removeAll()
                    session.llmDetectedItems.removeAll()
                }

                if session.confirmedTotal > 0 && !session.rawReceiptText.isEmpty && session.expectedItemCount > 0 {
                    await session.processWithBothApproaches(
                        confirmedTax: session.confirmedTax,
                        confirmedTip: session.confirmedTip,
                        confirmedTotal: session.confirmedTotal,
                        expectedItemCount: session.expectedItemCount
                    )
                }
            }
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
                } else {
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
                } else if let error = result.error {
                    validationError = error
                    showValidationAlert = true
                } else if result.needsContact {
                    // This shouldn't happen for saved contacts, but handle gracefully
                    validationError = "Unable to add contact to bill"
                    showValidationAlert = true
                }
            }
        }
    }
    
    private func handleExistingContactSelected(_ contact: TransactionContact) {
        Task {
            // Use proper validation for existing contacts to ensure strict security
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
                } else if let error = result.error {
                    validationError = error
                    showValidationAlert = true
                } else if result.needsContact {
                    // This shouldn't happen for existing contacts, but handle gracefully
                    validationError = "Unable to add contact to bill"
                    showValidationAlert = true
                }
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
                
                await MainActor.run {
                    if result.participant != nil {
                        newParticipantName = ""
                        showAddParticipantOptions = false
                    } else if result.needsContact {
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

// MARK: - Participant Chip Component

// MARK: - View Modifiers

private struct ContactPickerSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onContactsSelected: ([CNContact]) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ContactPicker(isPresented: $isPresented, onContactSelected: onContactsSelected)
            }
    }
}

private struct NewContactModalSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    let prefilledEmail: String
    let onContactSaved: (TransactionContact) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NewContactModal(
                    contactsManager: contactsManager,
                    authViewModel: authViewModel,
                    prefilledEmail: prefilledEmail,
                    onContactSaved: onContactSaved
                )
            }
    }
}

private struct ImagePopupCoverModifier: ViewModifier {
    @Binding var isPresented: Bool
    let image: UIImage?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                if let image = image {
                    ImagePopupView(image: image) {
                        isPresented = false
                    }
                }
            }
    }
}

private struct ValidationAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?

    func body(content: Content) -> some View {
        content
            .alert("❌ Error", isPresented: $isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "An error occurred.")
            }
    }
}

private struct SuccessAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?

    func body(content: Content) -> some View {
        content
            .alert("✅ Success", isPresented: $isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "Operation completed successfully.")
            }
    }
}

extension View {
    func contactPickerSheet(
        isPresented: Binding<Bool>,
        onContactsSelected: @escaping ([CNContact]) -> Void
    ) -> some View {
        modifier(ContactPickerSheetModifier(
            isPresented: isPresented,
            onContactsSelected: onContactsSelected
        ))
    }

    func newContactModalSheet(
        isPresented: Binding<Bool>,
        contactsManager: ContactsManager,
        authViewModel: AuthViewModel,
        prefilledEmail: String,
        onContactSaved: @escaping (TransactionContact) -> Void
    ) -> some View {
        modifier(NewContactModalSheetModifier(
            isPresented: isPresented,
            contactsManager: contactsManager,
            authViewModel: authViewModel,
            prefilledEmail: prefilledEmail,
            onContactSaved: onContactSaved
        ))
    }

    func imagePopupCover(
        isPresented: Binding<Bool>,
        image: UIImage?
    ) -> some View {
        modifier(ImagePopupCoverModifier(
            isPresented: isPresented,
            image: image
        ))
    }

    func validationAlert(
        isPresented: Binding<Bool>,
        message: String?
    ) -> some View {
        modifier(ValidationAlertModifier(
            isPresented: isPresented,
            message: message
        ))
    }

    func successAlert(
        isPresented: Binding<Bool>,
        message: String?
    ) -> some View {
        modifier(SuccessAlertModifier(
            isPresented: isPresented,
            message: message
        ))
    }
}

struct ParticipantChip: View {
    let participant: UIParticipant
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Text(participant.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if canDelete {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, canDelete ? 10 : 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(participant.color)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Remove Participant", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to remove \(participant.name) from this bill split? Any items assigned to them will become unassigned.")
        }
    }
}

// UIParticipant and UIItem are now in Models/DataModels.swift

struct UIItemAssignCard: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    
    var assignedParticipant: UIParticipant? {
        participants.first { $0.id == item.assignedTo }
    }
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPriceFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Editable Item Name
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $item.name)
                        .fontWeight(.medium)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Editable Price
                HStack(spacing: 4) {
                    Text("$")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Price", value: $item.price, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                        .fixedSize()
                        .focused($isPriceFieldFocused)
                        .onSubmit {
                            isPriceFieldFocused = false
                        }
                }
                
                if let assigned = assignedParticipant {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assigned.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            )
                        Text(assigned.name)
                            .font(.caption)
                    }
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            if assignedParticipant == nil {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(participants) { participant in
                        Button(participant.name) {
                            item.assignedTo = participant.id
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(participant.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(assignedParticipant != nil ? Color.adaptiveDepth1.opacity(0.5) : Color.adaptiveDepth0)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(assignedParticipant != nil ? Color.adaptiveTextTertiary.opacity(0.3) : Color.adaptiveTextTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Regex Item Card (Read-only display)
struct RegexItemCard: View {
    let item: ReceiptItem
    let participants: [UIParticipant]
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Item Name (Read-only)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Price (Read-only)
                Text("$\(String(format: "%.2f", item.price))")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Regex badge
                Text("REGEX")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentOrange.opacity(0.2))
                    .foregroundColor(.adaptiveAccentOrange)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Editable Regex Item Card
struct EditableRegexItemCard: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPriceFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Editable Item Name
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $item.name)
                        .fontWeight(.medium)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Editable Price
                HStack(spacing: 4) {
                    Text("$")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Price", value: $item.price, format: .number)
                        .keyboardType(.decimalPad)
                        .fixedSize()
                        .focused($isPriceFieldFocused)
                        .onSubmit {
                            isPriceFieldFocused = false
                        }
                }
                
                // Regex badge
                Text("REGEX")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentOrange.opacity(0.2))
                    .foregroundColor(.adaptiveAccentOrange)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Apple Intelligence Item Card (Read-only display)
struct LLMItemCard: View {
    let item: ReceiptItem
    let participants: [UIParticipant]
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Item Name (Read-only)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Price (Read-only)
                Text("$\(String(format: "%.2f", item.price))")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Apple Intelligence badge
                Text("APPLE AI")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentBlue.opacity(0.2))
                    .foregroundColor(.adaptiveAccentBlue)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Summary Screen

struct UISummaryScreen: View {
    let session: BillSplitSession
    let onDone: () -> Void
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var billManager: BillManager
    let existingBill: Bill?  // Optional for edit mode

    @StateObject private var billService = BillService()
    @State private var isCreatingBill = false
    @State private var billCreationError: String?
    @State private var showingError = false
    @State private var createdBill: Bill?
    @State private var expandedPersonIds: Set<String> = []
    @State private var showBillNameError = false

    init(
        session: BillSplitSession,
        onDone: @escaping () -> Void,
        contactsManager: ContactsManager,
        authViewModel: AuthViewModel,
        billManager: BillManager,
        existingBill: Bill? = nil
    ) {
        self.session = session
        self.onDone = onDone
        _contactsManager = ObservedObject(wrappedValue: contactsManager)
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        _billManager = ObservedObject(wrappedValue: billManager)
        self.existingBill = existingBill
    }

    private var isEditMode: Bool {
        existingBill != nil
    }

    var defaultBillName: String {
        return "Unnamed Bill"
    }

    // Extract complex paid by section
    @ViewBuilder
    private var paidBySection: some View {
        if let paidByID = session.paidByParticipantID,
           let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {
            HStack(spacing: .spacingSM) {
                // Profile picture or fallback avatar
                if let photoURLString = paidByParticipant.photoURL, let photoURL = URL(string: photoURLString) {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(paidByParticipant.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.captionText)
                            )
                    }
                } else {
                    Circle()
                        .fill(paidByParticipant.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.captionText)
                        )
                }

                Text(paidByParticipant.name)
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

    // Extract bill name editing section
    @ViewBuilder
    private var billNameSection: some View {
        TextField("Enter bill name (e.g., \"Dinner at Olive Garden\")", text: Binding(
            get: { session.billName },
            set: { newValue in
                session.billName = newValue
                // Hide error when user starts typing
                if showBillNameError && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showBillNameError = false
                }
            }
        ))
        .font(.bodyText)
        .foregroundColor(.adaptiveTextPrimary)
        .padding(.spacingMD)
        .background(Color.adaptiveDepth3)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.15), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.04 : 0.08), radius: 2, x: 0, y: 1)
        .autocorrectionDisabled()
        .padding(.horizontal, .paddingScreen)
    }

    @Environment(\.colorScheme) var colorScheme

    // Extract complex "Who Owes Whom" section
    @ViewBuilder
    private var whoOwesWhomSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Who Owes Whom")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.paddingScreen)

            if let paidByID = session.paidByParticipantID,
               let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) {

                // Calculate individual debts to the payer
                ForEach(session.individualDebts.sorted(by: { $0.key < $1.key }), id: \.key) { participantID, amountOwed in
                    if let debtor = session.participants.first(where: { $0.id == participantID }),
                       amountOwed > 0.01 { // Only show significant amounts

                        VStack(spacing: 0) {
                            Divider()

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
                            .padding(.paddingScreen)
                        }
                    }
                }

                // Show "No debts" message if everyone paid their share
                if session.individualDebts.allSatisfy({ $0.value <= 0.01 }) {
                    VStack(spacing: .spacingSM) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.adaptiveAccentGreen)
                            .font(.h3)
                        Text("Everyone paid their share!")
                            .font(.bodyDynamic)
                            .fontWeight(.medium)
                            .foregroundColor(.adaptiveAccentGreen)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.paddingScreen)
                }
            } else {
                // Error state - no payer selected
                VStack(spacing: .spacingSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.adaptiveAccentRed)
                        .font(.h3)
                    Text("Error: No payer selected")
                        .font(.bodyDynamic)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveAccentRed)
                }
                .frame(maxWidth: .infinity)
                .padding(.paddingScreen)
            }
        }
        .background(Color.adaptiveDepth1.opacity(0.3))
    }

    // Extract detailed breakdown section with collapsible person cards
    @ViewBuilder
    private var detailedBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Detailed breakdown")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.paddingScreen)
                .padding(.bottom, .spacingSM)

            ForEach(session.breakdownSummaries) { person in
                collapsiblePersonCard(for: person)
            }

            // Bottom padding for the section
            Spacer()
                .frame(height: .spacingMD)
        }
    }

    // Collapsible person card with "who owes whom" information
    @ViewBuilder
    private func collapsiblePersonCard(for person: UIBreakdown) -> some View {
        let isExpanded = expandedPersonIds.contains(person.id)
        let totalOwed = person.items.reduce(0.0) { $0.currencyAdd($1.price) }

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
                                .fill(person.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Group {
                                        if person.name == "Shared" {
                                            Text("S")
                                                .font(.captionText)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        } else {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        }
                                    }
                                )
                        }
                    } else {
                        Circle()
                            .fill(person.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Group {
                                    if person.name == "Shared" {
                                        Text("S")
                                            .font(.captionText)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                    }
                                }
                            )
                    }

                    // Person name with "owes" information
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.adaptiveTextPrimary)

                        // Show who this person owes (if they owe money)
                        if let paidByID = session.paidByParticipantID,
                           let paidByParticipant = session.participants.first(where: { $0.id == paidByID }),
                           let personID = session.participants.first(where: { $0.name == person.name })?.id,
                           let amountOwed = session.individualDebts[personID],
                           amountOwed > 0.01 {
                            Text("owes \(paidByParticipant.name): $\(amountOwed, specifier: "%.2f")")
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

    @ViewBuilder
    private func personBreakdownHeader(for person: UIBreakdown) -> some View {
        HStack {
            Circle()
                .fill(person.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Group {
                        if person.name == "Shared" {
                            Text("S")
                                .font(.captionText)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.captionText)
                        }
                    }
                )
            Text(person.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.adaptiveTextPrimary)
            Spacer()
        }
        .padding(.paddingScreen)
        .background(Color.adaptiveDepth1.opacity(0.3))
    }

    @ViewBuilder
    private func itemRow(name: String, price: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name)
                    .font(.bodyDynamic)
                    .foregroundColor(.adaptiveTextPrimary)
                Spacer()
                Text("$\(price, specifier: "%.2f")")
                    .font(.bodyDynamic)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveTextPrimary)
            }
            .padding(.paddingScreen)

            Divider()
        }
    }

    @ViewBuilder
    private func personSubtotalRow(for person: UIBreakdown) -> some View {
        HStack {
            Text("Subtotal")
                .font(.bodyDynamic)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextPrimary)
            Spacer()
            Text("$\(person.items.reduce(0) { $0.currencyAdd($1.price) }, specifier: "%.2f")")
                .font(.bodyDynamic)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextPrimary)
        }
        .padding(.paddingScreen)
        .background(Color.adaptiveDepth1.opacity(0.3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // SECTION 1: Header + Bill Name + Bill Info (white background)
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Summary")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.paddingScreen)

                    // Bill name editing (no padding, close to header)
                    billNameSection

                    // Bill name error card
                    if showBillNameError {
                        HStack(spacing: .spacingMD) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                            Text("Please enter a bill name")
                                .font(.bodyDynamic)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.spacingMD)
                        .background(Color.adaptiveAccentRed)
                        .cornerRadius(.cornerRadiusSmall)
                        .padding(.horizontal, .paddingScreen)
                        .padding(.top, .spacingSM)
                    }

                    // Bill info (with spacing above to separate from bill name)
                    VStack(alignment: .leading, spacing: .spacingSM) {
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
                            Text("$\(session.totalAmount, specifier: "%.2f")")
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)
                        }

                        HStack {
                            Text("Date & Time")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text("\(Date().formatted(date: .abbreviated, time: .shortened))")
                                .font(.bodyDynamic)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                    }
                    .padding(.top, .spacingLG)
                    .padding(.horizontal, .paddingScreen)
                    .padding(.bottom, .paddingScreen)
                }
                .background(Color.adaptiveDepth0)

                // SECTION 2: Detailed breakdown with collapsible person cards (light gray background)
                detailedBreakdownSection

                // SECTION 3: Add Bill Button (white background)
                VStack(spacing: .spacingMD) {
                    if isCreatingBill || !session.isReadyForBillCreation {
                        Button(action: {}) {
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
                        }
                        .buttonStyle(DisabledPrimaryButtonStyle())
                        .disabled(true)
                        .padding(.horizontal)
                    } else {
                        Button(action: {
                            Task {
                                await createBill()
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Bill")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                    }

                    // Show error if bill creation fails
                    if let error = billCreationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.adaptiveAccentRed)
                            Text(error)
                                .font(.captionDynamic)
                                .foregroundColor(.adaptiveAccentRed)
                        }
                        .padding(.top, .spacingSM)
                    }
                }
                .padding(.paddingScreen)
                .background(Color.adaptiveDepth0)
            }
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
        // Check if bill name is empty
        if session.billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showBillNameError = true
            return
        }

        // Clear bill name error if it was showing
        showBillNameError = false

        guard session.isReadyForBillCreation else {
            billCreationError = session.billCreationErrorMessage ?? "Session is not ready for bill creation"
            showingError = true
            return
        }

        isCreatingBill = true
        billCreationError = nil

        do {

            if isEditMode, let existingBillToUpdate = existingBill {
                // EDIT MODE: Update existing bill

                // Convert session data to bill format
                let updatedItems = session.assignedItems.map { assignedItem in
                    BillItem(
                        name: assignedItem.name,
                        price: assignedItem.price,
                        participantIDs: Array(assignedItem.assignedToParticipants)
                    )
                }

                // Build participants array
                var updatedParticipants: [BillParticipant] = []
                for uiParticipant in session.participants {
                    let displayName: String
                    let email: String

                    if uiParticipant.name == "You" {
                        displayName = authViewModel.user?.displayName ?? "You"
                        email = authViewModel.user?.email ?? ""
                    } else {
                        displayName = uiParticipant.name
                        // Find contact in transactionContacts
                        let matchingContact = contactsManager.transactionContacts.first { $0.displayName == uiParticipant.name }
                        email = matchingContact?.email ?? ""
                    }

                    let participant = BillParticipant(
                        userID: uiParticipant.id,
                        displayName: displayName,
                        email: email,
                        photoURL: uiParticipant.photoURL
                    )
                    updatedParticipants.append(participant)
                }

                guard let currentUserId = authViewModel.user?.uid,
                      let currentUserEmail = authViewModel.user?.email else {
                    billCreationError = "User not authenticated"
                    showingError = true
                    isCreatingBill = false
                    return
                }

                // Call updateBill on BillService
                try await billService.updateBill(
                    billId: existingBillToUpdate.id,
                    billName: session.billName,
                    items: updatedItems,
                    participants: updatedParticipants,
                    paidByParticipantId: session.paidByParticipantID ?? currentUserId,
                    currentUserId: currentUserId,
                    currentUserEmail: currentUserEmail,
                    billManager: billManager
                )

                // Call the completion handler
                onDone()

            } else {
                // CREATE MODE: Create new bill

                let bill = try await billService.createBill(
                    from: session,
                    authViewModel: authViewModel,
                    contactsManager: contactsManager
                )

                createdBill = bill

                // Add bill activity to history tracking for ALL participants
                if let currentUser = authViewModel.user {
                    let participantEmails = bill.participants.map { $0.email }
                    billManager.addBillActivity(
                        billId: bill.id,
                        billName: bill.billName ?? "Unnamed Bill",
                        activityType: .created,
                        actorName: currentUser.displayName ?? "Unknown User",
                        actorEmail: currentUser.email ?? "",
                        participantEmails: participantEmails,
                        participantIds: bill.participantIds,
                        amount: bill.totalAmount,
                        currency: bill.currency
                    )
                }

                // Call the completion handler
                onDone()
            }

        } catch {

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

// UISummary, UISummaryParticipant, UIBreakdown, and UIBreakdownItem are now in Models/DataModels.swift

// MARK: - Profile Screen

struct UIProfileScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var billManager: BillManager
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeletionError = false
    @State private var deletionErrorMessage = ""

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Background color
                Color.adaptiveDepth0.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        userInfoSection
                        menuItemsSection
                        Spacer(minLength: 150)
                    }
                    .padding(.top)
                }

                VStack(spacing: 12) {
                    logoutButton
                    appInfoSection
                }
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                handleDeleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
        }
        .alert("Cannot Delete Account", isPresented: $showDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        Text("Profile")
            .font(.h3Dynamic)
            .foregroundColor(.adaptiveTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .paddingScreen)
    }

    private var userInfoSection: some View {
        HStack(spacing: .spacingMD) {
            userAvatar

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(authViewModel.user?.displayName ?? "User")
                    .font(.h4Dynamic)
                    .foregroundColor(.adaptiveTextPrimary)
                Text(authViewModel.user?.email ?? "No email")
                    .font(.bodyDynamic)
                    .foregroundColor(.adaptiveTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, .paddingScreen)
    }

    private var userAvatar: some View {
        AsyncImage(url: authViewModel.user?.photoURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color.adaptiveDepth2)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.h3)
                        .foregroundColor(.adaptiveTextSecondary)
                )
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private var menuItemsSection: some View {
        VStack(spacing: .spacingSM) {
            NavigationLink(destination: NotificationsSettingsView().environmentObject(authViewModel)) {
                HStack {
                    HStack(spacing: .spacingMD) {
                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .foregroundColor(.adaptiveTextSecondary)
                            .frame(width: 24)

                        Text("Notifications")
                            .font(.bodyDynamic)
                            .foregroundColor(.adaptiveTextPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.captionText)
                        .foregroundColor(.adaptiveTextSecondary)
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth1)
                .cornerRadius(.cornerRadiusMedium)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            }

            NavigationLink(destination: HelpSupportView(
                billManager: billManager,
                showDeleteAccountConfirmation: $showDeleteAccountConfirmation
            )
            .environmentObject(authViewModel)) {
                HStack {
                    HStack(spacing: .spacingMD) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.adaptiveTextSecondary)
                            .frame(width: 24)

                        Text("Help & Support")
                            .font(.bodyDynamic)
                            .foregroundColor(.adaptiveTextPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.captionText)
                        .foregroundColor(.adaptiveTextSecondary)
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth1)
                .cornerRadius(.cornerRadiusMedium)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            }
        }
        .padding(.horizontal, .paddingScreen)
    }


    private var logoutButton: some View {
        Button(action: { authViewModel.signOut() }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                Text("Log Out")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.adaptiveTextTertiary.opacity(0.8))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    private var appInfoSection: some View {
        Text("SplitSmart v1.0.0")
            .font(.caption)
            .foregroundColor(.adaptiveTextSecondary)
            .padding(.bottom, 16)
    }

    // MARK: - Helper Methods

    private func handleDeleteAccount() {
        Task {
            do {
                try await authViewModel.deleteAccount(billManager: billManager)
                // Account deleted successfully - user will be automatically logged out
            } catch {
                // Show error to user
                await MainActor.run {
                    deletionErrorMessage = error.localizedDescription
                    showDeletionError = true
                }
            }
        }
    }
}

struct UIProfileMenuItem: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 24)

                    Text(title)
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.adaptiveDepth1)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Help & Support View

struct HelpSupportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var billManager: BillManager
    @Binding var showDeleteAccountConfirmation: Bool

    var body: some View {
        List {
            Section {
                Button(action: {
                    showDeleteAccountConfirmation = true
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.adaptiveAccentRed)
                                .frame(width: 24)

                            Text("Delete Account")
                                .foregroundColor(.adaptiveAccentRed)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Permanently delete your account and all associated data")
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notifications Settings View

struct NotificationsSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("billUpdatesEnabled") private var billUpdatesEnabled = true
    @AppStorage("paymentRemindersEnabled") private var paymentRemindersEnabled = true
    @AppStorage("newBillsEnabled") private var newBillsEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            } header: {
                Text("General")
            } footer: {
                Text("Allow SplitSmart to send you notifications")
            }

            Section {
                Toggle("Bill Updates", isOn: $billUpdatesEnabled)
                    .disabled(!notificationsEnabled)

                Toggle("Payment Reminders", isOn: $paymentRemindersEnabled)
                    .disabled(!notificationsEnabled)

                Toggle("New Bills", isOn: $newBillsEnabled)
                    .disabled(!notificationsEnabled)
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which types of notifications you want to receive")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Participant Assignment Row Component
struct ParticipantAssignmentRow: View {
    let item: UIItem
    let participants: [UIParticipant]
    let onParticipantToggle: (String) -> Void
    let onParticipantRemove: (String) -> Void
    let everyoneSelected: Bool
    let onEveryoneToggle: () -> Void

    @State private var showingFeedback = false
    @State private var feedbackParticipant: String? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { // Increased spacing from 8 to 12 for better industry standards
                // Everyone button styled like other participant buttons
                Button(action: {
                    onEveryoneToggle()
                    triggerFeedback(for: "everyone") // Use "everyone" for everyone button
                }) {
                    HStack(spacing: 6) {
                        Text("Everyone")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if everyoneSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, everyoneSelected ? 10 : 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(everyoneSelected ? Color.indigo : Color(.systemGray5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.indigo, lineWidth: everyoneSelected ? 0 : 1)
                            )
                    )
                    .foregroundColor(everyoneSelected ? .white : .indigo)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Vertical separator
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 1, height: 24)
                
                // Individual participant buttons
                ForEach(participants, id: \.id) { participant in
                    ParticipantButton(
                        participant: participant,
                        isAssigned: item.assignedToParticipants.contains(participant.id),
                        isDisabled: everyoneSelected,
                        onTap: {
                            if !everyoneSelected {
                                onParticipantToggle(participant.id)
                                triggerFeedback(for: participant.id)
                            }
                        },
                        onRemove: {
                            if !everyoneSelected {
                                onParticipantRemove(participant.id)
                                triggerFeedback(for: participant.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8) // Add vertical padding to prevent cut-off borders
        }
        .frame(minHeight: 60) // Increased height to accommodate padding and prevent border cut-off
    }
    
    private func triggerFeedback(for participantId: String) {
        feedbackParticipant = participantId
        showingFeedback = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reset feedback state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingFeedback = false
            feedbackParticipant = nil
        }
    }
}

// MARK: - Participant Button Component
struct ParticipantButton: View {
    let participant: UIParticipant
    let isAssigned: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) { // Increased spacing from 4 to 6
                Text(participant.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if isAssigned && !isDisabled {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, isAssigned ? 10 : 14) // Increased horizontal padding
            .padding(.vertical, 8) // Increased vertical padding from 6 to 8
            .background(
                RoundedRectangle(cornerRadius: 18) // Increased corner radius from 16 to 18
                    .fill(isAssigned ? participant.color.opacity(isDisabled ? 0.6 : 1.0) : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(participant.color.opacity(isDisabled ? 0.6 : 1.0), lineWidth: isAssigned ? 0 : 1)
                    )
            )
            .foregroundColor(isAssigned ? .white : participant.color.opacity(isDisabled ? 0.6 : 1.0))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !isDisabled {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Item Row with Participant Assignment
struct ItemRowWithParticipants: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    let onItemUpdate: (UIItem) -> Void

    @State private var showingSuccessAnimation = false
    @State private var isEveryoneSelected = false
    @State private var priceInput: String = ""
    @State private var isAssignSectionExpanded = true
    @FocusState private var isPriceFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Item name and price (label-left, value-right layout)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.adaptiveTextPrimary)

                    // Assignment status text label underneath item name
                    if item.assignedToParticipants.isEmpty {
                        Text("Unassigned")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Price input field on the right with $ label
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.adaptiveTextSecondary)
                    TextField("0.00", text: $priceInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.adaptiveTextPrimary)
                        .multilineTextAlignment(.trailing)
                        .focused($isPriceFocused)
                        .onChange(of: priceInput) { newValue in
                            updatePriceFromInput(newValue)
                        }
                }
                .frame(width: 140)
                .padding(.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .fill(Color.adaptiveDepth3)
                        .shadow(color: isPriceFocused ? Color.adaptiveAccentBlue.opacity(0.3) : Color.black.opacity(0.08), radius: isPriceFocused ? 10 : 8, x: 0, y: isPriceFocused ? 4 : 3)
                        .shadow(color: isPriceFocused ? Color.adaptiveAccentBlue.opacity(0.15) : Color.black.opacity(0.04), radius: isPriceFocused ? 4 : 2, x: 0, y: 1)
                )
                .animation(.easeOut(duration: 0.2), value: isPriceFocused)
            }

            // Cost per participant (if assigned)
            if !item.assignedToParticipants.isEmpty {
                HStack {
                    Text("Per person")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.adaptiveTextSecondary)

                    Spacer()

                    Text("$\(item.costPerParticipant, specifier: "%.2f")")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.adaptiveTextSecondary)
                }
            }

            // Participant assignment section with collapse/expand
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Header with collapse/expand
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isAssignSectionExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 0) {
                            Text("Assign to")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.adaptiveTextSecondary)

                            Spacer()

                            if !isAssignSectionExpanded {
                                // Show assigned participants when collapsed
                                Text(assignedParticipantsText)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.adaptiveTextSecondary)
                                    .padding(.trailing, 8)
                            }

                            Image(systemName: isAssignSectionExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .padding(.trailing, 8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Assignment buttons (shown when expanded)
                    if isAssignSectionExpanded {
                        ParticipantAssignmentRow(
                            item: item,
                            participants: participants,
                            onParticipantToggle: { participantId in
                                toggleParticipant(participantId)
                            },
                            onParticipantRemove: { participantId in
                                removeParticipant(participantId)
                            },
                            everyoneSelected: isEveryoneSelected,
                            onEveryoneToggle: {
                                toggleEveryoneButton()
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            updateEveryoneButtonState()
            initializePriceInput()
        }
        .onChange(of: item.assignedToParticipants) {
            updateEveryoneButtonState()
        }
    }

    private var assignedParticipantsText: String {
        if item.assignedToParticipants.isEmpty {
            return "Not assigned"
        }

        let assignedNames = participants
            .filter { item.assignedToParticipants.contains($0.id) }
            .map { $0.name }

        if assignedNames.count == participants.count {
            return "Everyone"
        } else if assignedNames.count == 1 {
            return "Assigned to: \(assignedNames[0])"
        } else {
            return "Assigned to: \(assignedNames.joined(separator: ", "))"
        }
    }
    
    private func toggleParticipant(_ participantId: String) {
        if item.assignedToParticipants.contains(participantId) {
            removeParticipant(participantId)
        } else {
            addParticipant(participantId)
        }
    }

    private func addParticipant(_ participantId: String) {
        item.assignedToParticipants.insert(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }

    private func removeParticipant(_ participantId: String) {
        item.assignedToParticipants.remove(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func triggerSuccessAnimation() {
        showingSuccessAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showingSuccessAnimation = false
        }
    }
    
    private func toggleEveryoneButton() {
        if isEveryoneSelected {
            // Deselect everyone - clear all assignments
            item.assignedToParticipants.removeAll()
            isEveryoneSelected = false
        } else {
            // Select everyone - assign to all participants
            item.assignedToParticipants = Set(participants.map { $0.id })
            isEveryoneSelected = true
        }
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func updateEveryoneButtonState() {
        let allParticipantIds = Set(participants.map { $0.id })
        isEveryoneSelected = !item.assignedToParticipants.isEmpty &&
                                 item.assignedToParticipants == allParticipantIds
    }

    private func initializePriceInput() {
        priceInput = String(format: "%.2f", item.price)
    }

    private func updatePriceFromInput(_ input: String) {
        // Remove any non-numeric characters except decimal point
        let filtered = input.filter { "0123456789.".contains($0) }

        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        let cleanedInput: String
        if components.count > 2 {
            cleanedInput = components[0] + "." + components[1...].joined()
        } else {
            cleanedInput = filtered
        }

        priceInput = cleanedInput

        // Update item price
        if let newPrice = Double(cleanedInput), newPrice >= 0 {
            item.price = newPrice
            onItemUpdate(item)
        }
    }
}
