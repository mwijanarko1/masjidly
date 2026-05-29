import Foundation

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String // SF Symbol name
}

struct WhatsNew {
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static var fullVersionString: String {
        "\(currentVersion) (\(currentBuild))"
    }

    static var latestUpdates: [WhatsNewItem] { localizedUpdates(locale: Locale(identifier: "en")) }

    static func localizedUpdates(locale: Locale) -> [WhatsNewItem] {
        let code = locale.language.languageCode?.identifier ?? String(locale.identifier.prefix(2))
        switch code {
        case "ar":
            return [
                WhatsNewItem(
                    title: "إصلاح: إقامة جدول المواعيد",
                    description: "تم إصلاح خطأ حيث كان جدول المواعيد يعرض أوقات إقامة العشاء بشكل غير صحيح لبعض المساجد. الآن الشاشة الرئيسية وجدول المواعيد والودجت تستخدم نفس المنطق.",
                    icon: "rectangle.grid.2x2"
                )
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکس: ٹائم ٹیبل اقامت",
                    description: "ایک بگ درست کیا گیا جہاں ٹائم ٹیبل بعض مساجد کے لیے عشاء کی غلط اقامت دکھا رہا تھا۔ اب ہوم، ٹائم ٹیبل اور وجٹس ایک ہی اقامت کا منطق استعمال کرتے ہیں۔",
                    icon: "rectangle.grid.2x2"
                )
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan: Iqamah Jadwal",
                    description: "Memperbaiki bug di jadwal yang menampilkan iqamah Isya yang salah untuk beberapa masjid. Layar utama, jadwal, dan widget kini menggunakan logika iqamah yang sama.",
                    icon: "rectangle.grid.2x2"
                )
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug Fix: Timetable Iqamah",
                    description: "Fixed a bug where the timetable showed incorrect Isha iqamah times for some mosques. Home, timetable, and widgets now use the same iqamah logic.",
                    icon: "rectangle.grid.2x2"
                )
            ]
        }
    }
}
