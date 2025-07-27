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
        VStack(spacing: 0) {
            // Compact Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Add Participants", text: $searchText)
                    .font(.subheadline)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Compact Dropdown Results
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
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else if isValidEmailOrPhone {
                        // New contact option in compact dropdown
                        Button(action: {
                            onNewContactSubmit(searchText)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.1))
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
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
                .zIndex(1000) // Ensure dropdown appears on top
            }
        }
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
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(contact.displayName.prefix(1).uppercased()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
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
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
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
                                    .foregroundColor(.red)
                            }
                            
                            TextField("Enter full name", text: $fullName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
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
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .keyboardType(.phonePad)
                        }
                        
                        // Error message
                        if let errorMessage = validationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
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

struct UIHomeScreen: View {
    let session: BillSplitSession
    let onCreateNew: () -> Void
    
    // For now, show empty state until we have real transaction history
    // TODO: Replace with actual transaction history from Firebase/persistence
    private var totalOwed: Double { 0.0 }
    private var totalOwe: Double { 0.0 }
    private var peopleWhoOweMe: [UIPersonDebt] { [] }
    private var peopleIOwe: [UIPersonDebt] { [] }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("SplitSmart")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal)
                
                // Balance Cards with exact React colors
                HStack(spacing: 12) {
                    // "You are owed" card - matching React green-50, green-100, green-800
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You are owed")
                            .font(.caption)
                            .foregroundColor(Color(red: 22/255, green: 101/255, blue: 52/255)) // green-800
                        
                        Text("$\(totalOwed, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 22/255, green: 101/255, blue: 52/255)) // green-800
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(red: 240/255, green: 253/255, blue: 244/255)) // green-50
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 187/255, green: 247/255, blue: 208/255), lineWidth: 1) // green-100
                    )
                    .cornerRadius(12)
                    
                    // "You owe" card - matching React red-50, red-100, red-800
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You owe")
                            .font(.caption)
                            .foregroundColor(Color(red: 153/255, green: 27/255, blue: 27/255)) // red-800
                        
                        Text("$\(totalOwe, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 153/255, green: 27/255, blue: 27/255)) // red-800
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(red: 254/255, green: 242/255, blue: 242/255)) // red-50
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 254/255, green: 202/255, blue: 202/255), lineWidth: 1) // red-100
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Create New Split Button
                Button(action: onCreateNew) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Split")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // People who owe you - simple list
                if !peopleWhoOweMe.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                            Text("People who owe you")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(peopleWhoOweMe) { person in
                                HStack {
                                    Circle()
                                        .fill(person.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(person.name)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("$\(person.total, specifier: "%.2f")")
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // People you owe - simple list
                if !peopleIOwe.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                            Text("People you owe")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(peopleIOwe) { person in
                                HStack {
                                    Circle()
                                        .fill(person.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(person.name)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("$\(person.total, specifier: "%.2f")")
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // All settled up message
                if peopleWhoOweMe.isEmpty && peopleIOwe.isEmpty {
                    VStack(spacing: 8) {
                        Text("All settled up!")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text("You have no outstanding balances")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Data Models are now in Models/DataModels.swift

// MARK: - Scan Screen
// UIScanScreen is now in Views/ScanView.swift

// MARK: - Assign Screen

struct UIAssignScreen: View {
    @ObservedObject var session: BillSplitSession
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
    @StateObject private var contactsManager = ContactsManager()
    
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
                        let canContinue = allItemsAssigned && totalComplete
                        
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
                        
                        if !allItemsAssigned {
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
            // Always trigger dual processing when screen appears to ensure fresh results
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
        .onAppear {
            // Initialize contacts manager with current user
            if let userId = authViewModel.user?.uid {
                print("🔍 DEBUG: Initializing contacts manager for user: \(userId)")
                contactsManager.setCurrentUser(userId)
                print("🔍 DEBUG: Current transaction contacts count: \(contactsManager.transactionContacts.count)")
            } else {
                print("⚠️ DEBUG: No user ID available for contacts manager")
                contactsManager.clearCurrentUser()
            }
        }
        .onChange(of: authViewModel.user?.uid) { oldUserId, newUserId in
            // Handle user changes (logout/login with different user)
            if let userId = newUserId {
                print("🔄 DEBUG: User changed, updating contacts manager for user: \(userId)")
                contactsManager.setCurrentUser(userId)
            } else {
                print("🧹 DEBUG: User logged out, clearing contacts manager")
                contactsManager.clearCurrentUser()
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

// MARK: - Participant Chip Component
struct ParticipantChip: View {
    let participant: UIParticipant
    let canDelete: Bool
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(participant.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
            Text(participant.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            if canDelete {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
        .background(assignedParticipant != nil ? Color.gray.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(assignedParticipant != nil ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
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
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
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
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
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
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
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
                
                // Bill paid by section
                VStack(spacing: 8) {
                    Text("Bill paid by You")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    HStack {
                        Text("Total amount:")
                        Spacer()
                        Text("$\(session.totalAmount, specifier: "%.2f")")
                            .fontWeight(.bold)
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
                
                // Who pays whom section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Who pays whom")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ForEach(session.participantSummaries.filter { $0.owes > 0 }) { participant in
                        HStack {
                            // From person
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(participant.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                    )
                                Text(participant.name)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            // To person (You)
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.caption)
                                    )
                                Text("You")
                            }
                            
                            Spacer()
                            
                            Text("$\(participant.owes, specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
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
                
                Button(action: onDone) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Mark as Settled")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
}

// UISummary, UISummaryParticipant, UIBreakdown, and UIBreakdownItem are now in Models/DataModels.swift

// MARK: - Profile Screen

struct UIProfileScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // User info section
                HStack(spacing: 16) {
                    AsyncImage(url: authViewModel.user?.photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.user?.displayName ?? "User")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(authViewModel.user?.email ?? "No email")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Menu items
                VStack(spacing: 8) {
                    UIProfileMenuItem(
                        icon: "gearshape",
                        title: "Account Settings"
                    )
                    
                    UIProfileMenuItem(
                        icon: "bell",
                        title: "Notifications"
                    )
                    
                    UIProfileMenuItem(
                        icon: "creditcard",
                        title: "Payment Methods"
                    )
                    
                    UIProfileMenuItem(
                        icon: "questionmark.circle",
                        title: "Help & Support"
                    )
                }
                .padding(.horizontal)
                
                // Debug section (for development)
                VStack(spacing: 8) {
                    Text("Debug Tools")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await authViewModel.createTestUser(
                                email: "test@example.com",
                                displayName: "Test User",
                                phoneNumber: "+1234567890"
                            )
                        }
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("Create Test User")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            let isRegistered = await authViewModel.isUserOnboarded(email: "test@example.com")
                            print("🔍 Test user registered: \(isRegistered)")
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.green)
                            Text("Check Test User")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            // Check if the current signed-in user can be found
                            if let currentEmail = authViewModel.user?.email {
                                let isRegistered = await authViewModel.isUserOnboarded(email: currentEmail)
                                print("🔍 Current user (\(currentEmail)) registered: \(isRegistered)")
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            Text("Check Current User")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Log out button
                Button(action: {
                    authViewModel.signOut()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Log Out")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // App info
                VStack(spacing: 4) {
                    Text("SplitSmart v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("© 2023 SplitSmart Inc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            .padding(.top)
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
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Participant Assignment Row Component
struct ParticipantAssignmentRow: View {
    let item: UIItem
    let participants: [UIParticipant]
    let onParticipantToggle: (Int) -> Void
    let onParticipantRemove: (Int) -> Void
    let everyoneSelected: Bool
    let onEveryoneToggle: () -> Void
    
    @State private var showingFeedback = false
    @State private var feedbackParticipant: Int? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { // Increased spacing from 8 to 12 for better industry standards
                // Everyone button styled like other participant buttons
                Button(action: {
                    onEveryoneToggle()
                    triggerFeedback(for: -1) // Use -1 for everyone button
                }) {
                    HStack(spacing: 6) {
                        Text("Everyone")
                            .font(.caption)
                            .fontWeight(.medium)
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
    
    private func triggerFeedback(for participantId: Int) {
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
                    .fontWeight(.medium)
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
    @State private var everyoneButtonSelected = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Item details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text("$\(item.price, specifier: "%.2f")")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if !item.assignedToParticipants.isEmpty {
                            Text("($\(item.costPerParticipant, specifier: "%.2f") each)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Assignment status indicator
                Circle()
                    .fill(item.assignedToParticipants.isEmpty ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(showingSuccessAnimation ? Color.green.opacity(0.3) : Color.clear)
                            .scaleEffect(showingSuccessAnimation ? 2.0 : 1.0)
                            .animation(.easeOut(duration: 0.4), value: showingSuccessAnimation)
                    )
            }
            
            // Horizontal line separator
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            // Participant assignment row
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assign to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Combined assignment row with Everyone button and participants
                    ParticipantAssignmentRow(
                        item: item,
                        participants: participants,
                        onParticipantToggle: { participantId in
                            toggleParticipant(participantId)
                        },
                        onParticipantRemove: { participantId in
                            removeParticipant(participantId)
                        },
                        everyoneSelected: everyoneButtonSelected,
                        onEveryoneToggle: {
                            toggleEveryoneButton()
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            updateEveryoneButtonState()
        }
        .onChange(of: item.assignedToParticipants) {
            updateEveryoneButtonState()
        }
    }
    
    private func toggleParticipant(_ participantId: Int) {
        if item.assignedToParticipants.contains(participantId) {
            removeParticipant(participantId)
        } else {
            addParticipant(participantId)
        }
    }
    
    private func addParticipant(_ participantId: Int) {
        item.assignedToParticipants.insert(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func removeParticipant(_ participantId: Int) {
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
        if everyoneButtonSelected {
            // Deselect everyone - clear all assignments
            item.assignedToParticipants.removeAll()
            everyoneButtonSelected = false
        } else {
            // Select everyone - assign to all participants
            item.assignedToParticipants = Set(participants.map { $0.id })
            everyoneButtonSelected = true
        }
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func updateEveryoneButtonState() {
        let allParticipantIds = Set(participants.map { $0.id })
        everyoneButtonSelected = !item.assignedToParticipants.isEmpty && 
                                 item.assignedToParticipants == allParticipantIds
    }
}