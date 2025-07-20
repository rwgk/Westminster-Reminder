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
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
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
        stopChiming() // Stop any existing timer
        
        // Schedule the next chime
        scheduleNextChime()
        isActive = true
        debugInfo = "Chiming started!"
    }
    
    func stopChiming() {
        timer?.invalidate()
        timer = nil
        isActive = false
        nextChimeTime = ""
        debugInfo = "Chiming stopped"
    }
    
    private func scheduleNextChime() {
        let now = Date()
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        
        // Calculate seconds until next 10-second mark
        let secondsUntilNext10 = (10 - (currentSecond % 10)) % 10
        let actualSecondsToWait = secondsUntilNext10 == 0 ? 10 : secondsUntilNext10
        
        let nextChimeDate = now.addingTimeInterval(Double(actualSecondsToWait))
        
        // Update UI
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        nextChimeTime = formatter.string(from: nextChimeDate)
        debugInfo = "Next chime in \(actualSecondsToWait) seconds at \(nextChimeTime)"
        
        // Schedule the timer
        timer = Timer.scheduledTimer(withTimeInterval: Double(actualSecondsToWait), repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.playChime()
                self?.scheduleNextChime() // Schedule the next one
            }
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
                
                Text("Get reminded to play Westminster chimes every 10 seconds!")
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
                        Text("🔔 Active - Next chime: \(chimeManager.nextChimeTime)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Test Sound") {
                        chimeManager.playTestSound()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 5) {
                    Text("Timer-based chiming:")
                        .font(.headline)
                    Text("Plays Bell sound every 10 seconds")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("(No notifications needed!)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if !chimeManager.debugInfo.isEmpty {
                        Text(chimeManager.debugInfo)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
