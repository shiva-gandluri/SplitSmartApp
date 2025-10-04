import SwiftUI
import Foundation

// MARK: - Epic 3: History Tab Real-Time Updates Implementation

struct HistoryView: View {
    @ObservedObject var billManager: BillManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: ActivityFilter = .all
    @State private var billNotFoundError = false
    @State private var billToDelete: Bill?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var selectedBill: Bill?
    @State private var showingBillDetail = false
    @State private var isLoadingBill = false

    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case created = "Created"
        case edited = "Edited" 
        case deleted = "Deleted"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .created: return "plus.circle"
            case .edited: return "pencil.circle"
            case .deleted: return "trash.circle"
            }
        }
    }
    
    var filteredActivities: [BillActivity] {
        switch selectedFilter {
        case .all:
            return billManager.billActivities
        case .created:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "created"
            }
        case .edited:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "edited"
            }
        case .deleted:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "deleted"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            mainContent
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            filterTabsSection
            contentSection
            errorSection
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingBillDetail) {
            if let bill = selectedBill {
                NavigationView {
                    BillDetailScreen(
                        bill: bill,
                        billManager: billManager,
                        authViewModel: authViewModel
                    )
                }
            }
        }
        .alert("Bill Not Found", isPresented: $billNotFoundError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("This bill may have been deleted or you no longer have access to it.")
        })
        .alert("Delete Bill", isPresented: $showingDeleteConfirmation, actions: deleteConfirmationActions, message: deleteConfirmationMessage)
        .onAppear(perform: setupHistoryTracking)
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                activityCountBadge
            }

            Text("All your bill activities")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    @ViewBuilder
    private var activityCountBadge: some View {
        if !billManager.billActivities.isEmpty {
            Text("\(filteredActivities.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
        }
    }

    private var filterTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ActivityFilter.allCases, id: \.rawValue) { filter in
                    FilterTab(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: countForFilter(filter)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var contentSection: some View {
        if billManager.isLoading {
            loadingView
        } else if filteredActivities.isEmpty {
            emptyStateView
        } else {
            activityListView
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading activities...")
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        EmptyHistoryView(filter: selectedFilter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activityListView: some View {
        List {
            ForEach(groupedActivities.keys.sorted(by: >), id: \.self) { date in
                activitySection(for: date)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshActivities()
        }
    }

    private func activitySection(for date: String) -> some View {
        Section(header: DateSectionHeader(date: date)) {
            ForEach(groupedActivities[date] ?? []) { activity in
                activityRow(for: activity)
            }
        }
    }

    private func activityRow(for activity: BillActivity) -> some View {
        Group {
            if let bill = billManager.userBills.first(where: { $0.id == activity.billId }) {
                // Bill is in active bills list (not deleted)
                NavigationLink(destination: BillDetailScreen(
                    bill: bill,
                    billManager: billManager,
                    authViewModel: authViewModel
                )) {
                    BillActivityRow(activity: activity) {}
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton(for: activity)
                }
            } else {
                // Bill might be deleted - fetch from Firestore
                BillActivityRow(activity: activity) {
                    Task {
                        await fetchAndShowBill(billId: activity.billId)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton(for: activity)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    /// Fetches bill by ID (including deleted bills) and shows detail screen
    private func fetchAndShowBill(billId: String) async {
        isLoadingBill = true

        if let bill = await billManager.getBillById(billId) {
            await MainActor.run {
                selectedBill = bill
                showingBillDetail = true
                isLoadingBill = false
            }
        } else {
            await MainActor.run {
                billNotFoundError = true
                isLoadingBill = false
            }
        }
    }

    @ViewBuilder
    private func deleteButton(for activity: BillActivity) -> some View {
        if canUserDeleteBill(activity: activity) {
            Button(role: .destructive) {
                handleDeleteBill(activity: activity)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = billManager.errorMessage {
            VStack {
                Text("Error loading activities")
                    .font(.headline)
                    .foregroundColor(.red)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Alert Content

    @ViewBuilder
    private func deleteConfirmationActions() -> some View {
        Button("Cancel", role: .cancel) {
            billToDelete = nil
        }
        Button("Delete", role: .destructive) {
            if let bill = billToDelete {
                Task {
                    await deleteBill(bill)
                }
            }
        }
    }

    @ViewBuilder
    private func deleteConfirmationMessage() -> some View {
        if let bill = billToDelete {
            Text("Are you sure you want to delete '\(bill.billName)'? This action cannot be undone.")
        } else {
            Text("Are you sure you want to delete this bill?")
        }
    }

    // MARK: - Helper Methods

    private func refreshActivities() async {
        if let userId = authViewModel.user?.uid {
            await billManager.refreshBills()
        }
    }
    
    // Group activities by date for better organization
    private var groupedActivities: [String: [BillActivity]] {
        Dictionary(grouping: filteredActivities) { activity in
            formatDateForGrouping(activity.timestamp)
        }
    }
    
    private func countForFilter(_ filter: ActivityFilter) -> Int {
        switch filter {
        case .all:
            return billManager.billActivities.count
        case .created:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "created"
            }.count
        case .edited:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "edited"
            }.count
        case .deleted:
            return billManager.billActivities.filter { activity in
                activity.activityType.rawValue == "deleted"
            }.count
        }
    }
    
    private func formatDateForGrouping(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func setupHistoryTracking() {
        guard let userId = authViewModel.user?.uid else { return }
        billManager.setCurrentUser(userId)
    }

    private func canUserDeleteBill(activity: BillActivity) -> Bool {
        // Only bill creator can delete
        guard let bill = billManager.userBills.first(where: { $0.id == activity.billId }),
              let currentUserId = authViewModel.user?.uid else {
            return false
        }
        return bill.paidBy == currentUserId || bill.createdBy == currentUserId
    }

    private func handleDeleteBill(activity: BillActivity) {
        if let bill = billManager.userBills.first(where: { $0.id == activity.billId }) {
            billToDelete = bill
            showingDeleteConfirmation = true
        }
    }

    private func deleteBill(_ bill: Bill) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            let billService = BillService()
            try await billService.deleteBill(
                billId: bill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )
            billToDelete = nil
            print("✅ Bill deleted successfully from history")
        } catch {
            print("❌ Failed to delete bill: \(error.localizedDescription)")
            // Show error to user (could add error state here)
        }
    }
}

// MARK: - Supporting Views

struct FilterTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
        }
    }
}

struct DateSectionHeader: View {
    let date: String
    
    var body: some View {
        Text(date)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 4)
    }
}

struct BillActivityRow: View {
    let activity: BillActivity
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Activity Icon
            Image(systemName: activity.activityType.systemIconName)
                .font(.title2)
                .foregroundColor(activity.activityType.iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                // Activity Description
                Text(activity.displayText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                // Amount and Time
                HStack {
                    Text(activity.formattedAmount)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatTime(activity.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyHistoryView: View {
    let filter: HistoryView.ActivityFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all: return "clock.badge.exclamationmark"
        case .created: return "plus.circle"
        case .edited: return "pencil.circle"
        case .deleted: return "trash.circle"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Activity Yet"
        case .created: return "No Bills Created"
        case .edited: return "No Bills Edited"
        case .deleted: return "No Bills Deleted"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "When you or others create, edit, or delete bills, they'll appear here with timestamps and attribution."
        case .created:
            return "Bills you or others create will appear here with creation details."
        case .edited:
            return "When bills are modified, you'll see the edit history here."
        case .deleted:
            return "Deleted bills are tracked here so you can see what was removed and by whom."
        }
    }
}

// MARK: - Bill Detail Screen (from Views/Screens - not in Xcode target)

struct BillDetailScreen: View {
    let bill: Bill
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var isCreator: Bool {
        authViewModel.user?.uid == bill.createdBy
    }

    private var billTotal: Double {
        bill.items.reduce(0) { $0 + $1.price }
    }

    private var creator: BillParticipant? {
        bill.participants.first { $0.id == bill.createdBy }
    }

    private var payer: BillParticipant? {
        bill.participants.first { $0.id == bill.paidBy }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                billOverviewSection
                participantsSection
                itemsSection

                if isCreator {
                    actionButtons
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Bill Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Bill", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteBill() }
            }
        } message: {
            Text("Are you sure you want to delete this bill? This action cannot be undone.")
        }
        .alert("Delete Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.billName ?? "Bill #\(bill.id.prefix(8))")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Created on \(bill.date.dateValue().formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if bill.isDeleted {
                        HStack {
                            Image(systemName: "trash.slash")
                                .foregroundColor(.red)
                            Text("DELETED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var billOverviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Total Amount:")
                    .font(.headline)
                Spacer()
                Text("$\(billTotal, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            if let creator = creator {
                HStack {
                    Text("Created by:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        Text(creator.displayName)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
            }

            if let payer = payer {
                HStack {
                    Text("Paid by:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "creditcard.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        Text(payer.displayName)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Owes What")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)

            let owedAmounts = BillCalculator.calculateOwedAmounts(bill: bill)

            if owedAmounts.isEmpty || owedAmounts.allSatisfy({ $0.value <= 0.01 }) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("All settled up!")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ForEach(owedAmounts.sorted(by: { $0.key < $1.key }), id: \.key) { participantId, amount in
                    if let debtor = bill.participants.first(where: { $0.id == participantId }),
                       let payer = payer,
                       amount > 0.01 {

                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
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

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
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

                            Text("$\(amount, specifier: "%.2f")")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items (\(bill.items.count))")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(bill.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .fontWeight(.medium)

                            Text("Split among \(item.participantIDs.count) people")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("$\(item.price, specifier: "%.2f")")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
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
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDeleting ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal)
    }

    @MainActor
    private func deleteBill() async {
        isDeleting = true
        deleteError = nil

        do {
            let billService = BillService()
            try await billService.deleteBill(
                billId: bill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )
            print("✅ Bill deleted successfully")
            dismiss()
        } catch {
            print("❌ Bill deletion failed: \(error.localizedDescription)")
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}

#Preview {
    HistoryView(billManager: BillManager())
        .environmentObject(AuthViewModel())
}