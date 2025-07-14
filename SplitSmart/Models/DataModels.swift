import SwiftUI

// MARK: - Data Models

// MARK: - Shared Transaction Models
struct UITransaction: Identifiable {
    let id = UUID()
    let personName: String
    let amount: Double
    let description: String
}

struct UIPersonDebt: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let color: Color
}

// MARK: - Assign Screen Models
struct UIParticipant: Identifiable, Hashable {
    let id: Int
    let name: String
    let color: Color
}

struct UIItem: Identifiable {
    let id: Int
    var name: String
    let price: Double
    var assignedTo: Int?
}

// MARK: - Summary Screen Models
struct UISummary {
    let restaurant: String
    let date: String
    let total: Double
    let paidBy: String
    let participants: [UISummaryParticipant]
    let breakdown: [UIBreakdown]
}

struct UISummaryParticipant: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let owes: Double
    let gets: Double
}

struct UIBreakdown: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let items: [UIBreakdownItem]
}

struct UIBreakdownItem {
    let name: String
    let price: Double
}