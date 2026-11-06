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
                    title: "مقارنة المساجد",
                    description: "قارن أوقات الأذان والإقامة بين المساجد، أو ابحث عن المسجد المناسب حسب الوقت.",
                    icon: "clock.badge.checkmark"
                ),
                WhatsNewItem(
                    title: "ودجات الشاشة الرئيسية",
                    description: "ثلاثة تصاميم جديدة تعرض الصلاة القادمة مع العد التنازلي.",
                    icon: "square.grid.2x2"
                ),
                WhatsNewItem(
                    title: "ودجات شاشة القفل",
                    description: "ستة تصاميم جديدة لمتابعة الصلاة القادمة من شاشة القفل.",
                    icon: "lock.iphone"
                ),
                WhatsNewItem(
                    title: "ترتيب علامات المساجد",
                    description: "اضغط مطولاً على علامة المسجد واسحبها لإعادة ترتيبها.",
                    icon: "arrow.up.arrow.down"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "مساجد کا موازنہ",
                    description: "مساجد کے درمیان اذان اور اقامت کے اوقات کا موازنہ کریں، یا وقت کے مطابق مسجد تلاش کریں۔",
                    icon: "clock.badge.checkmark"
                ),
                WhatsNewItem(
                    title: "ہوم اسکرین ویجٹس",
                    description: "اگلی نماز اور کاؤنٹ ڈاؤن دکھانے والے تین نئے ڈیزائن۔",
                    icon: "square.grid.2x2"
                ),
                WhatsNewItem(
                    title: "لاک اسکرین ویجٹس",
                    description: "لاک اسکرین سے اگلی نماز دیکھنے کے لیے چھ نئے ڈیزائن۔",
                    icon: "lock.iphone"
                ),
                WhatsNewItem(
                    title: "مساجد کی ترتیب",
                    description: "مسجد کے ٹیب کو دبائے رکھیں اور گھسیٹ کر ترتیب بدلیں۔",
                    icon: "arrow.up.arrow.down"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Bandingkan masjid",
                    description: "Bandingkan waktu adzan dan iqamah antar masjid, atau cari masjid berdasarkan waktu.",
                    icon: "clock.badge.checkmark"
                ),
                WhatsNewItem(
                    title: "Widget layar utama",
                    description: "Tiga desain baru yang menampilkan salat berikutnya dengan hitung mundur.",
                    icon: "square.grid.2x2"
                ),
                WhatsNewItem(
                    title: "Widget layar kunci",
                    description: "Enam desain baru untuk melihat salat berikutnya dari layar kunci.",
                    icon: "lock.iphone"
                ),
                WhatsNewItem(
                    title: "Urutkan tab masjid",
                    description: "Tekan lama tab masjid lalu seret untuk mengubah urutannya.",
                    icon: "arrow.up.arrow.down"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Compare Masjids",
                    description: "Compare adhan and iqamah times across masjids, or find a masjid by time.",
                    icon: "clock.badge.checkmark"
                ),
                WhatsNewItem(
                    title: "Home Screen Widgets",
                    description: "Three new designs showing your next prayer with a live countdown.",
                    icon: "square.grid.2x2"
                ),
                WhatsNewItem(
                    title: "Lock Screen Widgets",
                    description: "Six new designs to check your next prayer from the Lock Screen.",
                    icon: "lock.iphone"
                ),
                WhatsNewItem(
                    title: "Reorder Masjid Tabs",
                    description: "Press and hold a masjid tab, then drag it to reorder.",
                    icon: "arrow.up.arrow.down"
                ),
            ]
        }
    }
}
