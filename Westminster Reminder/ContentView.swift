import SwiftUI
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}

class ChimeManager: ObservableObject {
    @Published var isActive = false
    @Published var debugInfo = ""
    @Published var nextChimeTime = ""
    @Published var timeToNextChime = ""
    
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var nextChimeDate: Date?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            debugInfo = "Audio session setup failed: \(error.localizedDescription)"
        }
    }
    
    func startChiming() {
        stopChiming() // Stop any existing timers
        
        // Schedule the next chime
        scheduleNextChime()
        startCountdown()
        isActive = true
        debugInfo = "Chiming started!"
    }
    
    func stopChiming() {
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        isActive = false
        nextChimeTime = ""
        timeToNextChime = ""
        nextChimeDate = nil
        debugInfo = "Chiming stopped"
    }
    
    private func scheduleNextChime() {
        let now = Date()
        let calendar = Calendar.current
        
        // Get current time components
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentSecond = calendar.component(.second, from: now)
        
        // Find the next quarter hour (00, 15, 30, 45)
        var nextMinute: Int
        var nextHour = currentHour
        
        if currentMinute < 15 {
            nextMinute = 15
        } else if currentMinute < 30 {
            nextMinute = 30
        } else if currentMinute < 45 {
            nextMinute = 45
        } else {
            nextMinute = 0
            nextHour = currentHour + 1
            if nextHour >= 24 {
                nextHour = 0
            }
        }
        
        // Create the target time: 20 seconds before the quarter hour
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextHour
        components.minute = nextMinute - 1  // One minute before
        components.second = 40  // 40 seconds = 20 seconds before the next minute
        
        guard let nextChimeDate = calendar.date(from: components) else {
            debugInfo = "Error calculating next chime time"
            return
        }
        
        // If the calculated time is in the past (edge case), add 15 minutes
        let finalChimeDate = nextChimeDate <= now ?
            calendar.date(byAdding: .minute, value: 15, to: nextChimeDate) ?? nextChimeDate :
            nextChimeDate
        
        // Store for countdown
        self.nextChimeDate = finalChimeDate
        
        let timeInterval = finalChimeDate.timeIntervalSinceNow
        
        // Update UI with "HH:MM -20 seconds" format
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Get the actual quarter hour time (not the -20 seconds time)
        let actualQuarterHour = calendar.date(byAdding: .second, value: 20, to: finalChimeDate) ?? finalChimeDate
        nextChimeTime = "\(formatter.string(from: actualQuarterHour)) -20 seconds"
        updateCountdown()
        debugInfo = "Next Westminster chime scheduled"
        
        // Schedule the timer
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.playChime()
                self?.scheduleNextChime() // Schedule the next one
                self?.startCountdown() // Restart countdown for next chime
            }
        }
    }
    
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateCountdown()
            }
        }
    }
    
    private func updateCountdown() {
        guard let nextChimeDate = nextChimeDate else {
            timeToNextChime = ""
            return
        }
        
        let timeInterval = nextChimeDate.timeIntervalSinceNow
        
        if timeInterval <= 0 {
            timeToNextChime = "🔔 Now!"
            return
        }
        
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            timeToNextChime = "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            timeToNextChime = "0:\(String(format: "%02d", seconds))"
        }
    }
    
    private func playChime() {
        // Play the system bell sound directly
        AudioServicesPlaySystemSound(1013) // Bell sound
        
        // Update debug info
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        debugInfo = "🔔 Chimed at \(formatter.string(from: Date()))"
    }
    
    func playTestSound() {
        AudioServicesPlaySystemSound(1013) // Same Bell sound
    }
}

struct ContentView: View {
    @StateObject private var chimeManager = ChimeManager()
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
                    Button(action: {
                        if chimeManager.isActive {
                            chimeManager.stopChiming()
                        } else {
                            chimeManager.startChiming()
                        }
                    }) {
                        Text(chimeManager.isActive ? "Stop Chiming" : "Start Chiming")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(chimeManager.isActive ? Color.red : Color.green)
                            .cornerRadius(10)
                    }
                    
                    if chimeManager.isActive {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Next")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Image(systemName: "bell.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text(":")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text(chimeManager.nextChimeTime)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Seconds to")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Image(systemName: "bell.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text(":")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text(chimeManager.timeToNextChime)
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: {
                        chimeManager.playTestSound()
                    }) {
                        HStack {
                            Text("Test")
                                .font(.title3)
                            Image(systemName: "bell.fill")
                                .font(.title3)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Text("Westminster Comfort")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .opacity(0.7)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
