import SwiftUI
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Play sound even when app is in foreground
        completionHandler([.sound])
    }
}

struct ContentView: View {
    @State private var isReminderActive = false
    @State private var notificationPermissionGranted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Westminster Reminder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Get reminded to play Westminster chimes every 15 minutes!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    if notificationPermissionGranted {
                        Button(action: {
                            if isReminderActive {
                                stopReminders()
                            } else {
                                startReminders()
                            }
                        }) {
                            Text(isReminderActive ? "Stop Reminders" : "Start Reminders")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isReminderActive ? Color.red : Color.green)
                                .cornerRadius(10)
                        }
                        
                        if isReminderActive {
                            Text("🔔 Active - You'll get notified 20 seconds before each quarter hour")
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Button("Enable Notifications") {
                            requestNotificationPermission()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        
                        Text("Notifications are required for reminders to work")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Button("Test Sound") {
                        playTestSound()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 5) {
                    Text("Reminders will play:")
                        .font(.headline)
                    Text("11:59:40, 12:14:40, 12:29:40, 12:44:40")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("(20 seconds before each quarter hour)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
            }
        }
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func startReminders() {
        // Clear any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let now = Date()
        
        // Create notifications for the next 30 days
        for dayOffset in 0..<30 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            // For each quarter hour: 00, 15, 30, 45
            for minute in [0, 15, 30, 45] {
                // Set time to 20 seconds before the minute
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                
                for hour in 0..<24 {
                    components.hour = hour
                    components.minute = minute
                    components.second = 40  // 20 seconds before the next minute
                    
                    guard let notificationDate = calendar.date(from: components) else { continue }
                    
                    // Only schedule if it's in the future
                    if notificationDate > now {
                        let content = UNMutableNotificationContent()
                        content.title = "Westminster Chime Time!"
                        content.body = "Time to play the chimes on your xylophone 🎵"
                        content.sound = UNNotificationSound(named: UNNotificationSoundName("bell.aiff"))
                        
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        
                        UNUserNotificationCenter.current().add(request)
                    }
                }
            }
        }
        
        isReminderActive = true
    }
    
    func stopReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        isReminderActive = false
    }
    
    func playTestSound() {
        // Play the same Bell sound that notifications will use
        AudioServicesPlaySystemSound(1013) // This is the Bell sound
    }
}
