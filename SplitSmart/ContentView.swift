import SwiftUI

struct ContentView: View {
    @State private var selectedTab = "home"
    
    var body: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case "home":
                UIHomeScreen { selectedTab = "scan" }
            case "groups":
                UIGroupsScreen()
            case "scan":
                UIScanScreen { selectedTab = "assign" }
            case "assign":
                UIAssignScreen { selectedTab = "summary" }
            case "summary":
                UISummaryScreen { selectedTab = "home" }
            case "history":
                UIHistoryScreen()
            case "profile":
                UIProfileScreen()
            default:
                UIHomeScreen { selectedTab = "scan" }
            }
            
            HStack {
                TabButton(icon: "house.fill", label: "Home", isSelected: selectedTab == "home") {
                    selectedTab = "home"
                }
                TabButton(icon: "person.2.fill", label: "Groups", isSelected: selectedTab == "groups") {
                    selectedTab = "groups"
                }
                TabButton(icon: "camera.fill", label: "Scan", isSelected: selectedTab == "scan") {
                    selectedTab = "scan"
                }
                TabButton(icon: "clock.fill", label: "History", isSelected: selectedTab == "history") {
                    selectedTab = "history"
                }
                TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == "profile") {
                    selectedTab = "profile"
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        }
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct UIGroupsScreen: View {
    var body: some View {
        VStack {
            Text("Groups")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Text("Groups functionality coming soon!")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct UIHistoryScreen: View {
    var body: some View {
        VStack {
            Text("History")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Text("Transaction history coming soon!")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}