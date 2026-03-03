//
//  NotificationManager.swift
//  Girella
//
//  Created by Elizbar Kheladze on 03/03/26.
//

import UserNotifications

@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notifications permission granted.")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleWaitNotification(for date: Date, message: String) {
        // Cancel any existing notifications first
        cancelAll()
        
        let content = UNMutableNotificationContent()
        content.title = "AWARE"
        content.body = message
        content.sound = .default
        
        // Calculate how many seconds from now the notification should fire
        let timeInterval = date.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "wait_timer_finished", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled notification for \(timeInterval) seconds from now: '\(message)'")
            }
        }
    }
    
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
