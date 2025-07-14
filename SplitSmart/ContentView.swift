import SwiftUI

struct ContentView: View {
    @State private var selectedTab = "home"
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
                    .environmentObject(authViewModel)
            default:
                UIHomeScreen { selectedTab = "scan" }
            }
            
            TabBarView(selectedTab: $selectedTab)
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: String
    
    var body: some View {
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

// TabButton is now in Components/TabButton.swift

struct UIGroupsScreen: View {
    var body: some View {
        ScrollView {
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
}

struct UIHistoryScreen: View {
    var body: some View {
        ScrollView {
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
}

#Preview {
    ContentView()
}