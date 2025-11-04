import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background matching other app screens
                Color.adaptiveDepth0.ignoresSafeArea()

                VStack(spacing: .spacing2XL) {
                    Spacer()

                    // App Branding
                    VStack(spacing: .spacingLG) {
                        // Animated App Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                // .shadow(color: .accentColor.opacity(0.3), radius: 20, x: 0, y: 10)

                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(isAnimating ? 1.05 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 2.0)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }

                        VStack(spacing: .spacingSM) {
                            Text("SplitSmart")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.accentColor, .purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("Split bills easily with friends")
                                .font(.h4Dynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, .paddingScreen)
                        }
                    }

                    Spacer()

                    // Sign In Section
                    VStack(spacing: .spacingLG) {
                        if authViewModel.isLoading {
                            VStack(spacing: .spacingMD) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.accentColor)
                                Text("Signing in...")
                                    .font(.bodyDynamic)
                                    .foregroundColor(.adaptiveTextSecondary)
                            }
                            .padding(.paddingSection)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusButton)
                                    .fill(Color.adaptiveDepth1)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                        } else {
                            // Simple Google Sign-In button
                            Button(action: {
                                Task {
                                    await authViewModel.signInWithGoogle()
                                }
                            }) {
                                HStack(spacing: .spacingSM) {
                                    Image(systemName: "person.crop.circle.fill")
                                    Text("Continue with Google")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        // Error message
                        if !authViewModel.errorMessage.isEmpty {
                            HStack(spacing: .spacingXS) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.captionDynamic)
                                    .foregroundColor(.adaptiveAccentRed)

                                Text(authViewModel.errorMessage)
                                    .font(.captionDynamic)
                                    .foregroundColor(.adaptiveAccentRed)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, .paddingScreen)
                            .padding(.vertical, .spacingSM)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                                    .fill(Color.adaptiveAccentRed.opacity(0.1))
                                    .stroke(Color.adaptiveAccentRed.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, .spacingLG)
                }
                .padding(.horizontal, .paddingSection)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
