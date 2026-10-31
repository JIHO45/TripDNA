import Foundation
import UserNotifications

enum EvaluationNotificationService {
    private static let enabledKey = "tripdna.evaluationNotificationsEnabled"

    static var isEnabled: Bool { AppStorageLocation.defaults.bool(forKey: enabledKey) }

    /// 설정에서 끈다. 예약돼 있던 평가 알림도 함께 거둔다.
    static func disable() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        AppStorageLocation.defaults.set(false, forKey: enabledKey)
    }

    static func enable(for trips: [Trip]) async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return false }
        AppStorageLocation.defaults.set(true, forKey: enabledKey)
        for trip in trips { try await scheduleIfEnabled(for: trip) }
        return true
    }

    static func scheduleIfEnabled(for trip: Trip) async throws {
        guard AppStorageLocation.defaults.bool(forKey: enabledKey) else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = notificationID(for: trip.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let end = trip.legs.map(\.endDate).max(), end > Date() else { return }
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)),
              let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextDay),
              fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "How was your trip?")
        content.body = String(localized: "Record this trip with ratings and notes for each city.")
        content.sound = .default
        content.userInfo = ["tripID": trip.id]
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await center.add(request)
    }

    static func cancel(for tripID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID(for: tripID)]
        )
    }

    static func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        AppStorageLocation.defaults.removeObject(forKey: enabledKey)
        AppStorageLocation.defaults.removeObject(forKey: TripRegistrationViewModel.notificationPrimingShownKey)
    }

    private static func notificationID(for tripID: String) -> String { "evaluation.\(tripID)" }
}
