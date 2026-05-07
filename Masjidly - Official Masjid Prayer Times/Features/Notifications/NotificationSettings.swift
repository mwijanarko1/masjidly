import Foundation

struct NotificationSettings: Codable, Equatable, Sendable {
    var masterEnabled: Bool = false
    var fajr: Bool = true
    var dhuhrJummah: Bool = true
    var asr: Bool = true
    var maghrib: Bool = true
    var isha: Bool = true
}
