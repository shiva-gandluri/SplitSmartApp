import SwiftUI
import Firebase
import FirebaseFirestore
// import FirebaseAppCheck  // Temporarily disabled until proper setup
import GoogleSignIn
import UserNotifications
// TODO: Add FirebaseMessaging via Xcode Package Dependencies
// import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate { // TODO: Add MessagingDelegate after adding FirebaseMessaging
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // TEMPORARILY DISABLED: Firebase App Check until proper setup is complete
        // The iOS app needs to be registered in Firebase Console first
        print("⚠️ Firebase App Check temporarily disabled - complete manual setup first")
        
        // Configure Firebase as early as possible
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // Configure Firestore settings with modern API
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        db.settings = settings
        print("✅ Firestore configured with offline persistence")
        
        // Configure Google Sign-In with client ID from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientID = plist["CLIENT_ID"] as? String else {
            print("❌ Failed to get CLIENT_ID from GoogleService-Info.plist")
            return false
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("✅ Google Sign-In configured with client ID: \(clientID)")
        
        // Configure Firebase Cloud Messaging
        setupPushNotifications(application: application)
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Google Sign-In URL scheme
        print("🔗 Handling URL: \(url.absoluteString)")
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Push Notification Setup
    
    private func setupPushNotifications(application: UIApplication) {
        print("🔔 Setting up basic push notifications (FCM integration pending)...")
        
        // TODO: Uncomment after adding FirebaseMessaging
        // Set FCM messaging delegate
        // Messaging.messaging().delegate = self
        
        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            if let error = error {
                print("❌ Failed to request notification authorization: \(error)")
                return
            }
            
            print(granted ? "✅ Notification authorization granted" : "⚠️ Notification authorization denied")
            
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ Successfully registered for remote notifications")
        print("📱 Device Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // TODO: Uncomment after adding FirebaseMessaging
        // Set APNs token for Firebase Messaging
        // Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - MessagingDelegate (TODO: Uncomment after adding FirebaseMessaging)
    /*
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCM token is nil")
            return
        }
        
        print("✅ FCM Registration Token received: \(fcmToken)")
        
        // Store token in Firestore when user is authenticated
        Task {
            await FCMTokenManager.shared.updateFCMToken(fcmToken)
        }
    }
    */
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        print("📩 Received notification while app is in foreground: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")
        
        // TODO: Navigate to specific bill detail if bill ID is provided
        if let billId = userInfo["billId"] as? String {
            print("🔍 Navigate to bill: \(billId)")
            // We'll implement navigation logic later
        }
        
        completionHandler()
    }
}

@main
struct SplitSmartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isInitializing {
                    // Show branded loading screen instead of blank screen
                    LoadingView()
                } else if authViewModel.isSignedIn {
                    ContentView()
                        .environmentObject(authViewModel)
                } else {
                    AuthView()
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var loadingText = "Loading..."
    @State private var dots = ""
    
    var body: some View {
        ZStack {
            // Gradient background similar to AuthView
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon and Branding
                VStack(spacing: 24) {
                    // Enhanced animated icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    
                    VStack(spacing: 12) {
                        Text("SplitSmart")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(loadingText + dots)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.5), value: dots)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            isAnimating = true
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation {
                if dots.count >= 3 {
                    dots = ""
                } else {
                    dots += "."
                }
            }
        }
    }
}