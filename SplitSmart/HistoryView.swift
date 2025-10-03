import SwiftUI
import Foundation

// MARK: - Epic 3: History Tab Real-Time Updates Implementation

struct HistoryView: View {
    @ObservedObject var billManager: BillManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: ActivityFilter = .all
    @State private var selectedBill: Bill?
    @State private var showingBillDetail = false
    @State private var billNotFoundError = false
    @State private var billToDelete: Bill?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        
                        // Activity count badge
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
                    
                    Text("All your bill activities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Filter Tabs
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
                
                // Content Area
                if billManager.isLoading {
                    Spacer()
                    ProgressView("Loading activities...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else if filteredActivities.isEmpty {
                    EmptyHistoryView(filter: selectedFilter)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Activity List
                    List {
                        ForEach(groupedActivities.keys.sorted(by: >), id: \.self) { date in
                            Section(header: DateSectionHeader(date: date)) {
                                ForEach(groupedActivities[date] ?? []) { activity in
                                    BillActivityRow(activity: activity) {
                                        handleBillTap(activity: activity)
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if canUserDeleteBill(activity: activity) {
                                            Button(role: .destructive) {
                                                handleDeleteBill(activity: activity)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        if let userId = authViewModel.user?.uid {
                            await billManager.refreshBills()
                        }
                    }
                }
                
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
            .alert("Bill Not Found", isPresented: $billNotFoundError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This bill may have been deleted or you no longer have access to it.")
            }
            .alert("Delete Bill", isPresented: $showingDeleteConfirmation) {
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
            } message: {
                if let bill = billToDelete {
                    Text("Are you sure you want to delete '\(bill.billName)'? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this bill?")
                }
            }
            .onAppear {
                setupHistoryTracking()
            }
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

    private func handleBillTap(activity: BillActivity) {
        // Find the bill in the current user's bills
        if let bill = billManager.userBills.first(where: { $0.id == activity.billId }) {
            selectedBill = bill
            showingBillDetail = true
        } else {
            // Bill not found - may have been deleted or user lost access
            billNotFoundError = true
        }
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
            try await billManager.deleteBill(billId: bill.id)
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
        Button(action: onTap) {
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
        }
        .buttonStyle(PlainButtonStyle())
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

#Preview {
    HistoryView(billManager: BillManager())
        .environmentObject(AuthViewModel())
}