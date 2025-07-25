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
    
    @State private var newParticipantName = ""
    @State private var showAddParticipant = false
    @State private var showContactPicker = false
    @State private var showAddParticipantOptions = false
    @State private var showingImagePopup = false
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
                
                // Participants Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Participants")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: {
                            showAddParticipantOptions = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.plus")
                                    .font(.body)
                                Text("Add Participant")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Add Participant Options
                    if showAddParticipantOptions {
                        VStack(spacing: 12) {
                            // Option 1: From Contacts
                            Button(action: handleChooseFromContacts) {
                                HStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "person.crop.circle")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Choose from Contacts")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("Select from your contact list")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            
                            // Option 2: Manual Entry
                            Button(action: {
                                showAddParticipantOptions = false
                                showAddParticipant = true
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "pencil")
                                                .font(.title3)
                                                .foregroundColor(.green)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enter Manually")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("Type the participant's name")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if showAddParticipant {
                        VStack(spacing: 12) {
                            TextField("Enter participant name", text: $newParticipantName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .onSubmit {
                                    handleAddParticipant()
                                }
                            
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    showAddParticipant = false
                                    newParticipantName = ""
                                }
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                                
                                Button("Add Participant") {
                                    handleAddParticipant()
                                }
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .disabled(newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
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
                        ForEach(convertReceiptItemsToUIItems(session.regexDetectedItems).indices, id: \.self) { index in
                            let uiItems = convertReceiptItemsToUIItems(session.regexDetectedItems)
                            EditableRegexItemCard(
                                item: Binding(
                                    get: { uiItems[index] },
                                    set: { newValue in
                                        // Update the session's regex items when edited
                                        session.regexDetectedItems[index] = ReceiptItem(
                                            name: newValue.name,
                                            price: newValue.price,
                                            confidence: newValue.confidence,
                                            originalDetectedName: newValue.originalDetectedName,
                                            originalDetectedPrice: newValue.originalDetectedPrice
                                        )
                                    }
                                ),
                                participants: session.participants
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
                                let regexTotal = session.regexDetectedItems.reduce(0) { $0 + $1.price }
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
                        let regexTotal = session.regexDetectedItems.reduce(0) { $0 + $1.price }
                        let regexTotalsMatch = abs(regexTotal - session.confirmedTotal) <= 0.01
                        
                        Button(action: {
                            // Set regex items as the active assignment
                            session.assignedItems = session.regexDetectedItems.enumerated().map { index, receiptItem in
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
                        ForEach(session.llmDetectedItems.indices, id: \.self) { index in
                            let item = session.llmDetectedItems[index]
                            LLMItemCard(
                                item: item,
                                participants: session.participants
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                
                // LLM Totals Section
                if !session.llmDetectedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apple Intelligence Totals")
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
                                let llmTotal = session.llmDetectedItems.reduce(0) { $0 + $1.price }
                                Text(String(format: "$%.2f", llmTotal))
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(abs(llmTotal - session.confirmedTotal) > 0.01 ? .red : .primary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        let llmTotal = session.llmDetectedItems.reduce(0) { $0 + $1.price }
                        let llmTotalsMatch = abs(llmTotal - session.confirmedTotal) <= 0.01
                        
                        Button(action: {
                            // Set LLM items as the active assignment
                            session.assignedItems = session.llmDetectedItems.enumerated().map { index, receiptItem in
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
                            splitSharedItems()
                            onContinue()
                        }) {
                            HStack {
                                Text("Continue with Apple Intelligence Results")
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(llmTotalsMatch ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!llmTotalsMatch)
                        .padding(.horizontal)
                        
                        if !llmTotalsMatch {
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
        
        for contact in contacts {
            let contactName = contact.displayName
            
            // Use session to add participant
            if let _ = session.addParticipant(name: contactName) {
                print("✅ Added participant: \(contactName)")
            } else {
                print("⚠️ Participant \(contactName) already exists, skipping")
            }
        }
        
        showContactPicker = false
        showAddParticipantOptions = false
    }
    
    private func deleteParticipant(_ participant: UIParticipant) {
        // Use session to remove participant (handles item unassignment automatically)
        session.removeParticipant(participant)
    }
    
    private func handleAddParticipant() {
        let trimmedName = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedName.isEmpty {
            if let _ = session.addParticipant(name: trimmedName) {
                print("✅ Added participant manually: \(trimmedName)")
            } else {
                print("⚠️ Participant \(trimmedName) already exists")
            }
            
            newParticipantName = ""
            showAddParticipant = false
            showAddParticipantOptions = false
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
                                Text("$\(person.items.reduce(0) { $0 + $1.price }, specifier: "%.2f")")
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