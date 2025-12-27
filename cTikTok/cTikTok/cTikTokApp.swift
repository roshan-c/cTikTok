import SwiftUI
import BackgroundTasks
import UserNotifications
import AVFoundation

/**
 * cTikTokApp is the main entry point for the app.
 * It is the root view controller and the main window.
 * It is responsible for configuring the app and the app delegate.
 */

@main
struct cTikTokApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App Delegate for Background Tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure audio session to play sound even when silent switch is on
        configureAudioSession()
        
        // Register background tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConfig.backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Schedule initial refresh
        scheduleAppRefresh()
        
        // Request notification permission
        Task {
            await requestNotificationPermission()
        }
        
        return true
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // .playback category ignores the silent switch
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Background Refresh
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                let lastCheck = UserDefaults.standard.object(forKey: "lastVideoCheck") as? Date ?? Date.distantPast
                let response = try await APIService.shared.checkForNewVideos(since: lastCheck)
                
                if response.hasNew {
                    await showLocalNotification(count: response.count)
                }
                
                UserDefaults.standard.set(Date(), forKey: "lastVideoCheck")
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
    
    private func showLocalNotification(count: Int) async {
        let center = UNUserNotificationCenter.current()
        
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Videos!"
        content.body = "\(count) new video\(count > 1 ? "s" : "") waiting for you"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await center.add(request)
    }
}
