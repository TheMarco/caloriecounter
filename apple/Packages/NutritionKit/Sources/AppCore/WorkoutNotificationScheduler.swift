// Local notifications for the "you finished a workout — offset it?" prompt, posted
// when HealthKit wakes the app in the background. Permission is requested lazily —
// only the first time a workout would actually be announced — so the user isn't
// prompted just for flipping the Settings toggle. Tapping the notification opens
// the app, where the Today banner offers the same Add / Dismiss.

import Foundation
import UserNotifications
import NutritionCore

enum WorkoutNotificationScheduler {
    /// Ask for notification permission if not already decided; returns whether we may
    /// post. Safe to call repeatedly (no prompt after the first decision).
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// Post a single notification for a completed workout. The request id is the
    /// workout UUID, so the system coalesces any accidental duplicate.
    static func post(_ workout: WorkoutSample) async {
        let content = UNMutableNotificationContent()
        content.title = "Workout complete"
        content.body = "You burned about \(Int(workout.kcal)) kcal in a "
            + "\(workout.durationMinutes)-min \(workout.activityName). Tap to add it to your calories."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "workout-\(workout.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
