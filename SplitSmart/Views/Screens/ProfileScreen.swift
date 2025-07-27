import SwiftUI

/**
 * Profile Screen - User Account Management Interface
 * 
 * User profile display with account management options and debug tools.
 * 
 * Features:
 * - User information display with avatar and details
 * - Account settings menu with navigation options
 * - Debug tools for development and testing
 * - User authentication management (sign out)
 * - App version and copyright information
 * 
 * Architecture: MVVM with EnvironmentObject for auth state
 * Integration: Async operations for user validation and test data
 */

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

/**
 * Profile Menu Item Component
 * 
 * Reusable menu item for profile settings navigation.
 * 
 * Features:
 * - Icon and title display
 * - Chevron indicator for navigation
 * - Consistent styling with shadow and corner radius
 * - Tap action handling (currently placeholder)
 */
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