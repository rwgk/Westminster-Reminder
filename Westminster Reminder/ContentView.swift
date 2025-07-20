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
    @Published var secondsBefore = 20 // Default 20 seconds
    @Published var nextQuarterHourTime = "" // Add this for the UI
    
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var nextChimeDate: Date?
    
    init() {
        setupAudioSession()
        loadSettings()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            debugInfo = "Audio session setup failed: \(error.localizedDescription)"
        }
    }
    
    private func loadSettings() {
        secondsBefore = UserDefaults.standard.integer(forKey: "secondsBefore")
        if secondsBefore == 0 { // First time
            secondsBefore = 20
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(secondsBefore, forKey: "secondsBefore")
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
        
        // Create the target time: X seconds before the quarter hour
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextHour
        components.minute = nextMinute
        components.second = -secondsBefore // X seconds before the minute start
        
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
        
        // Update UI with the next quarter hour time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Calculate the actual quarter hour time that we're chiming before
        var quarterComponents = calendar.dateComponents([.year, .month, .day], from: finalChimeDate)
        quarterComponents.hour = nextHour
        quarterComponents.minute = nextMinute
        quarterComponents.second = 0
        
        let actualQuarterHour = calendar.date(from: quarterComponents) ?? finalChimeDate
        let quarterHourTime = formatter.string(from: actualQuarterHour)
        nextQuarterHourTime = quarterHourTime // Store for UI
        nextChimeTime = "unused" // We'll build this in the UI now
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
    @State private var showingSecondsPicker = false
    
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
                            HStack(spacing: 4) {
                                Text("Next")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Image(systemName: "bell.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text(":")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Button(action: {
                                    showingSecondsPicker = true
                                }) {
                                    Text("\(chimeManager.secondsBefore)")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                Text("seconds before")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text(chimeManager.nextQuarterHourTime)
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
        .sheet(isPresented: $showingSecondsPicker) {
            SecondsPickerView(secondsBefore: $chimeManager.secondsBefore,
                            isPresented: $showingSecondsPicker,
                            onSave: {
                                chimeManager.saveSettings()
                                if chimeManager.isActive {
                                    chimeManager.startChiming() // Restart with new timing
                                }
                            })
        }
    }
}

struct SecondsPickerView: View {
    @Binding var secondsBefore: Int
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    // Smart granularity for seconds
    private var secondsOptions: [Int] {
        var options: [Int] = []
        
        // 0-10: every second
        for i in 0...10 {
            options.append(i)
        }
        
        // 15-60: every 5 seconds
        for i in stride(from: 15, through: 60, by: 5) {
            options.append(i)
        }
        
        // 70-120: every 10 seconds
        for i in stride(from: 70, through: 120, by: 10) {
            options.append(i)
        }
        
        return options
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Chime before quarter hour")
                    .font(.headline)
                    .padding()
                
                Picker("Seconds", selection: $secondsBefore) {
                    ForEach(secondsOptions, id: \.self) { seconds in
                        Text("\(seconds) second\(seconds == 1 ? "" : "s")")
                            .tag(seconds)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Timing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                }
            }
        }
    }
}
