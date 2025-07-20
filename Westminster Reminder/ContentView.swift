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
        // Play sound even when app is in foreground - need both sound and list for iOS 15+
        if #available(iOS 14.0, *) {
            completionHandler([.sound, .list])
        } else {
            completionHandler([.sound])
        }
    }
}

struct ContentView: View {
    @State private var isReminderActive = false
    @State private var notificationPermissionGranted = false
    @State private var scheduledCount = 0
    @State private var debugInfo = ""
    
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
                    
                    Button("Check Scheduled Notifications") {
                        checkScheduledNotifications()
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    
                    Button("Check Notification Settings") {
                        checkNotificationSettings()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
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
                    
                    if scheduledCount > 0 {
                        Text("📅 \(scheduledCount) notifications scheduled")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        
        // Show current time in the app
        debugInfo = "Current: \(formatter.string(from: now))"
        
        // Find the next 10-second mark
        let currentSecond = calendar.component(.second, from: now)
        let secondsUntilNext10 = (10 - (currentSecond % 10)) % 10
        let secondsUntilNext10OrNow = secondsUntilNext10 == 0 ? 10 : secondsUntilNext10
        
        // Schedule 12 notifications, every 10 seconds
        var scheduledCount = 0
        for i in 0..<12 {
            let timeInterval = Double(secondsUntilNext10OrNow + (i * 10))
            
            let content = UNMutableNotificationContent()
            content.title = "Test Chime #\(i + 1)"
            content.body = "Westminster test notification 🎵"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("sms-received5.caf"))
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let request = UNNotificationRequest(identifier: "test-chime-\(i)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if error == nil {
                    scheduledCount += 1
                }
            }
        }
        
        // Calculate first notification time for display
        let firstNotificationDate = now.addingTimeInterval(Double(secondsUntilNext10OrNow))
        
        // Update debug info
        debugInfo = "Current: \(formatter.string(from: now))\nFirst test: \(formatter.string(from: firstNotificationDate))\nIn \(secondsUntilNext10OrNow) seconds\n12 notifications every 10s"
        
        isReminderActive = true
        self.scheduledCount = 12
    }
    
    func stopReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        isReminderActive = false
        scheduledCount = 0
    }
    
    func checkScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.scheduledCount = requests.count
                if requests.count > 0 {
                    let nextRequest = requests.first!
                    if let trigger = nextRequest.trigger as? UNCalendarNotificationTrigger,
                       let nextFireDate = trigger.nextTriggerDate() {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        formatter.timeStyle = .medium
                        self.debugInfo = "Next: \(formatter.string(from: nextFireDate))"
                    }
                } else {
                    self.debugInfo = "No notifications scheduled"
                }
            }
        }
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                var settingsInfo = "Auth: \(settings.authorizationStatus.rawValue)\n"
                settingsInfo += "Sound: \(settings.soundSetting.rawValue)\n"
                settingsInfo += "Alert: \(settings.alertSetting.rawValue)\n"
                settingsInfo += "Badge: \(settings.badgeSetting.rawValue)"
                self.debugInfo = settingsInfo
            }
        }
    }
    
    func playTestSound() {
        // Play the same Bell sound that notifications will use
        AudioServicesPlaySystemSound(1013) // This is the Bell sound (sms-received5.caf)
    }
}
