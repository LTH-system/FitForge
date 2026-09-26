import Foundation
import UserNotifications

/// 夕食前・週次ふりかえりのローカル通知。内容は固定文で、記録データそのものは含めない
/// （ローカル通知はスケジュールした時点の内容しか表示できず、配信時に残りカロリー等を
/// 計算し直すことはできないため）
enum NotificationService {
    private static let dinnerIdentifier = "fitforge.dinnerReminder"
    private static let weeklyReviewIdentifier = "fitforge.weeklyReview"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }

    /// 現在の設定に合わせて、通知を登録し直す
    static func apply(_ settings: NotificationSettings) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dinnerIdentifier, weeklyReviewIdentifier])

        if settings.dinnerReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "そろそろ夕食の時間です"
            content.body = "今日の残りのカロリーとたんぱく質を確認して、夕食を記録しましょう。"
            content.sound = .default

            var date = DateComponents()
            date.hour = settings.dinnerReminderHour
            date.minute = settings.dinnerReminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            center.add(UNNotificationRequest(identifier: dinnerIdentifier, content: content, trigger: trigger))
        }

        if settings.weeklyReviewReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "今週のふりかえりを見てみましょう"
            content.body = "体重の変化、平均摂取、自己ベストをまとめて確認できます。"
            content.sound = .default

            var date = DateComponents()
            date.weekday = settings.weeklyReviewWeekday
            date.hour = settings.weeklyReviewHour
            date.minute = settings.weeklyReviewMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            center.add(UNNotificationRequest(identifier: weeklyReviewIdentifier, content: content, trigger: trigger))
        }
    }
}
