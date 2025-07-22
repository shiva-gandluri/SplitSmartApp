import SwiftUI

struct ContentView: View {
    @State private var selectedTab = "home"
    @State private var isKeyboardVisible = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var billSplitSession = BillSplitSession()
    
    var showBackButton: Bool {
        return ["scan", "assign", "summary"].contains(selectedTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button for navigation flows
            if showBackButton {
                HStack {
                    Button(action: handleBackAction) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    Spacer()
                }
            }
            
            switch selectedTab {
            case "home":
                UIHomeScreen(session: billSplitSession) { 
                    billSplitSession.startNewSession()
                    selectedTab = "scan" 
                }
            case "groups":
                UIGroupsScreen()
            case "scan":
                UIScanScreen(session: billSplitSession) { 
                    selectedTab = "assign" 
                }
            case "assign":
                UIAssignScreen(session: billSplitSession) { 
                    billSplitSession.completeAssignment()
                    selectedTab = "summary" 
                }
            case "summary":
                UISummaryScreen(session: billSplitSession) { 
                    billSplitSession.completeSession()
                    selectedTab = "home" 
                }
            case "history":
                UIHistoryScreen()
            case "profile":
                UIProfileScreen()
                    .environmentObject(authViewModel)
            default:
                UIHomeScreen(session: billSplitSession) { 
                    billSplitSession.startNewSession()
                    selectedTab = "scan" 
                }
            }
            
            // Only show TabBar when keyboard is not visible
            if !isKeyboardVisible {
                TabBarView(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func handleBackAction() {
        switch selectedTab {
        case "scan":
            selectedTab = "home"
        case "assign":
            // When going back from assign to scan, reset the session for fresh upload
            billSplitSession.resetSession()
            billSplitSession.sessionState = .scanning
            selectedTab = "scan"
        case "summary":
            selectedTab = "assign"
        default:
            selectedTab = "home"
        }
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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