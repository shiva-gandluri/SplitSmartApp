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
    @EnvironmentObject var billManager: BillManager

    var body: some View {
        NavigationView {
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
                    NavigationLink(destination: NotificationsSettingsView().environmentObject(authViewModel)) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "bell")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)

                                Text("Notifications")
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

                // Delete Account Button
                Button(action: {
                    showDeleteAccountConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.top)
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                handleDeleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
        }
        .alert("Cannot Delete Account", isPresented: $showDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage)
        }
    }

    // MARK: - Delete Account Logic

    @State private var showDeleteAccountConfirmation = false
    @State private var showDeletionError = false
    @State private var deletionErrorMessage = ""

    private func handleDeleteAccount() {
        Task {
            do {
                try await authViewModel.deleteAccount(billManager: billManager)
                // Account deleted successfully - user will be automatically logged out
            } catch {
                // Show error to user
                await MainActor.run {
                    deletionErrorMessage = error.localizedDescription
                    showDeletionError = true
                }
            }
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

/**
 * Notifications Settings View
 *
 * Allow users to manage their notification preferences
 */
struct NotificationsSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("billUpdatesEnabled") private var billUpdatesEnabled = true
    @AppStorage("paymentRemindersEnabled") private var paymentRemindersEnabled = true
    @AppStorage("newBillsEnabled") private var newBillsEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            } header: {
                Text("General")
            } footer: {
                Text("Allow SplitSmart to send you notifications")
            }

            Section {
                Toggle("Bill Updates", isOn: $billUpdatesEnabled)
                    .disabled(!notificationsEnabled)

                Toggle("Payment Reminders", isOn: $paymentRemindersEnabled)
                    .disabled(!notificationsEnabled)

                Toggle("New Bills", isOn: $newBillsEnabled)
                    .disabled(!notificationsEnabled)
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which types of notifications you want to receive")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}