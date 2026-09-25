import Foundation
import UserNotifications

enum EvaluationNotificationService {
    private static let enabledKey = "tripdna.evaluationNotificationsEnabled"

    static func enable(for trips: [Trip]) async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return false }
        UserDefaults.standard.set(true, forKey: enabledKey)
        for trip in trips { try await scheduleIfEnabled(for: trip) }
        return true
    }

    static func scheduleIfEnabled(for trip: Trip) async throws {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = notificationID(for: trip.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let end = trip.legs.map(\.endDate).max(), end > Date() else { return }
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)),
              let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextDay),
              fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "여행은 어떠셨나요?"
        content.body = "30초만에 이번 여행을 평가하고 다음 추천을 더 정확하게 만들어 보세요."
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
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: TripRegistrationViewModel.notificationPrimingShownKey)
    }

    private static func notificationID(for tripID: String) -> String { "evaluation.\(tripID)" }
}
