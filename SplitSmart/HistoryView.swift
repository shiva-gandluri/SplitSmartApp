import SwiftUI
import Foundation

// MARK: - Epic 3: History Tab Real-Time Updates Implementation

struct HistoryView: View {
    @ObservedObject var billManager: BillManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: ActivityFilter = .all
    @State private var showingBillNotFoundAlert = false
    @State private var billToDelete: Bill?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var selectedBill: Bill?
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
                .background(Color.adaptiveDepth0.ignoresSafeArea())
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
        .sheet(item: $selectedBill) { bill in
            NavigationView {
                BillDetailScreen(
                    bill: bill,
                    billManager: billManager,
                    authViewModel: authViewModel
                )
            }
            .onAppear {
                if let deletedBy = bill.deletedBy {
                }
            }
        }
        .alert("Bill Not Found", isPresented: $showingBillNotFoundAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("This bill may have been deleted or you no longer have access to it.")
        })
        .alert("Delete Bill", isPresented: $showingDeleteConfirmation, actions: deleteConfirmationActions, message: deleteConfirmationMessage)
        .onAppear(perform: setupHistoryTracking)
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: .spacingSM) {
            HStack {
                Text("History")
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveTextPrimary)
            }
        }
        .padding(.top, .spacingMD)
        .padding(.horizontal, .paddingScreen)
    }

    @ViewBuilder
    private var activityCountBadge: some View {
        if !billManager.billActivities.isEmpty {
            Text("\(filteredActivities.count)")
                .font(.captionDynamic)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, .spacingSM)
                .padding(.vertical, .spacingXS)
                .background(Color.adaptiveAccentBlue)
                .clipShape(Capsule())
        }
    }

    private var filterTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacingMD) {
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
            .padding(.horizontal, .paddingScreen)
        }
        .padding(.vertical, .spacingSM)
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
            ForEach(sortedDateKeys(), id: \.self) { date in
                activitySection(for: date)
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveDepth0)
        .refreshable {
            await refreshActivities()
        }
    }

    // Sort date strings by converting them to Date objects for proper chronological ordering
    private func sortedDateKeys() -> [String] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return groupedActivities.keys.sorted { dateString1, dateString2 in
            guard let date1 = formatter.date(from: dateString1),
                  let date2 = formatter.date(from: dateString2) else {
                return dateString1 > dateString2 // Fallback to string comparison if parsing fails
            }
            return date1 > date2 // Newest first
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
        // Always fetch fresh bill data to ensure correct isDeleted status
        // This prevents showing Delete button on already-deleted bills
        BillActivityRow(activity: activity) {
            Task {
                await fetchAndShowBill(billId: activity.billId)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteButton(for: activity)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.adaptiveDepth0)
    }

    /// Fetches bill by ID (including deleted bills) and shows detail screen
    private func fetchAndShowBill(billId: String) async {
        isLoadingBill = true

        if let bill = await billManager.getBillById(billId) {
            if let deletedBy = bill.deletedBy {
            }
            await MainActor.run {
                selectedBill = bill
                isLoadingBill = false
            }
        } else {
            await MainActor.run {
                showingBillNotFoundAlert = true
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
                    .font(.h4Dynamic)
                    .foregroundColor(.adaptiveAccentRed)
                Text(errorMessage)
                    .font(.captionDynamic)
                    .foregroundColor(.adaptiveTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.paddingCard)
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
        } catch {
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
            HStack(spacing: .spacingXS) {
                Image(systemName: icon)
                    .font(.captionText)
                Text(title)
                    .font(.captionDynamic)
                    .fontWeight(.medium)
                if count > 0 {
                    Text("\(count)")
                        .font(.captionText)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .adaptiveTextSecondary)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.adaptiveDepth2)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .adaptiveTextPrimary)
            .padding(.horizontal, .spacingMD)
            .padding(.vertical, .spacingSM)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.adaptiveAccentBlue : Color.adaptiveDepth1)
            )
        }
    }
}

struct DateSectionHeader: View {
    let date: String

    var body: some View {
        Text(date)
            .font(.smallDynamic)
            .fontWeight(.semibold)
            .foregroundColor(.adaptiveTextPrimary)
            .padding(.vertical, .spacingXS)
    }
}

struct BillActivityRow: View {
    let activity: BillActivity
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: .spacingMD) {
            // Activity Icon
            Image(systemName: activity.activityType.systemIconName)
                .font(.h3)
                .foregroundColor(activity.activityType.iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: .spacingXS) {
                // Activity Description
                Text(activity.displayText)
                    .font(.bodyDynamic)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveTextPrimary)
                    .multilineTextAlignment(.leading)

                // Amount and Time
                HStack {
                    Text(activity.formattedAmount)
                        .font(.captionDynamic)
                        .foregroundColor(.adaptiveTextSecondary)

                    Spacer()

                    Text(formatTime(activity.timestamp))
                        .font(.captionDynamic)
                        .foregroundColor(.adaptiveTextSecondary)
                }
            }
        }
        .padding(.vertical, .spacingXS)
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
        VStack(spacing: .spacingMD) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.adaptiveTextSecondary)

            VStack(spacing: .spacingSM) {
                Text(emptyStateTitle)
                    .font(.h3Dynamic)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveTextPrimary)

                Text(emptyStateMessage)
                    .font(.bodyDynamic)
                    .foregroundColor(.adaptiveTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .paddingSection)
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

// MARK: - Bill Detail Screen
// Using canonical implementation from Views/Screens/BillDetailScreen.swift

#Preview {
    HistoryView(billManager: BillManager())
        .environmentObject(AuthViewModel())
}