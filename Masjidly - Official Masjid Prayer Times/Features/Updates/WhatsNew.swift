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
                    title: "عدّاد الأذان والإقامة",
                    description: "شاهد العدّاد المباشر للأذان التالي على الشاشة الرئيسية. اضغط على دائرة القبلة لرؤية عدّادات الأذان والإقامة معاً.",
                    icon: "timer"
                ),
                WhatsNewItem(
                    title: "ثيم الصلاة المخصص",
                    description: "اختر بين الوضع الديناميكي والثابت. الوضع الديناميكي يتبع ألوان وقت الصلاة الحالي؛ الثابت يثبت على ثيم صلاتك المفضلة. الإعدادات > الثيم.",
                    icon: "paintpalette"
                ),
                WhatsNewItem(
                    title: "دعم تعدد اللغات",
                    description: "يتحدث مسجدلي الآن بلغتك. بدّل بين الإنجليزية والعربية والأردية والإندونيسية، وستتغير أسماء الصلوات والإعدادات والإشعارات والودجات فوراً.",
                    icon: "globe"
                ),
                WhatsNewItem(
                    title: "تخطيط عربي وأردي من اليمين إلى اليسار",
                    description: "دعم كامل لاتجاه الواجهة من اليمين إلى اليسار للعربية والأردية، بما يشمل الشاشة الرئيسية والإعدادات والشرح التمهيدي.",
                    icon: "text.alignright"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "اذان اور اقامت کاؤنٹ ڈاؤن",
                    description: "ہوم اسکرین پر اگلی اذان کا براہِ راست کاؤنٹ ڈاؤن دیکھیں۔ اذان اور اقامت دونوں کے کاؤنٹ ڈاؤن دیکھنے کے لیے قبلہ سرکل کو دبائیں۔",
                    icon: "timer"
                ),
                WhatsNewItem(
                    title: "اپنی مرضی کا نماز تھیم",
                    description: "ڈائنامک اور فکسڈ تھیم میں سے انتخاب کریں۔ ڈائنامک موجودہ نماز کے وقت کے رنگوں کی پیروی کرتا ہے؛ فکسڈ آپ کے پسندیدہ نماز تھیم کو مقفل کرتا ہے۔ ترتیبات > تھیم۔",
                    icon: "paintpalette"
                ),
                WhatsNewItem(
                    title: "کئی زبانوں کی سہولت",
                    description: "مسجدلی اب آپ کی زبان بولتا ہے۔ انگریزی، عربی، اردو اور انڈونیشیائی میں تبدیلی کریں؛ نمازوں کے نام، ترتیبات، اطلاعات اور وجٹس فوراً بدل جاتے ہیں۔",
                    icon: "globe"
                ),
                WhatsNewItem(
                    title: "عربی اور اردو RTL لے آؤٹ",
                    description: "عربی اور اردو کے لیے دائیں سے بائیں مکمل لے آؤٹ، جس میں ہوم اسکرین، ترتیبات اور آن بورڈنگ خوبصورتی سے شامل ہیں۔",
                    icon: "text.alignright"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Hitung Mundur Adzan & Iqamah",
                    description: "Lihat hitung mundur langsung ke adzan berikutnya di layar utama. Ketuk lingkaran qiblah untuk melihat hitung mundur ke waktu adzan dan iqamah.",
                    icon: "timer"
                ),
                WhatsNewItem(
                    title: "Tema Salat Kustom",
                    description: "Pilih antara mode Dinamis dan Tetap. Dinamis mengikuti warna langit waktu salat saat ini; Tetap mengunci ke tema salat favorit Anda. Pengaturan > Tema.",
                    icon: "paintpalette"
                ),
                WhatsNewItem(
                    title: "Dukungan Banyak Bahasa",
                    description: "Masjidly kini berbicara dalam bahasa Anda. Beralih antara Inggris, Arab, Urdu, dan Indonesia; nama salat, pengaturan, notifikasi, dan widget langsung menyesuaikan.",
                    icon: "globe"
                ),
                WhatsNewItem(
                    title: "Tata Letak RTL Arab & Urdu",
                    description: "Dukungan penuh kanan-ke-kiri untuk Arab dan Urdu, termasuk layar utama, pengaturan, dan onboarding.",
                    icon: "text.alignright"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Adhan & Iqamah Countdown",
                    description: "See the live countdown to the next adhan on the home screen. Tap the qiblah circle to see countdowns to both adhan and iqamah times.",
                    icon: "timer"
                ),
                WhatsNewItem(
                    title: "Custom Prayer Theme",
                    description: "Choose between Dynamic and Fixed theme modes. Dynamic follows the current prayer time's sky colours; Fixed locks to your favourite prayer theme. Settings > Theme.",
                    icon: "paintpalette"
                ),
                WhatsNewItem(
                    title: "Multi-Language Support",
                    description: "Masjidly now speaks your language. Switch between English, Arabic, Urdu, and Indonesian. Prayer names, settings, notifications, and widgets all adapt instantly.",
                    icon: "globe"
                ),
                WhatsNewItem(
                    title: "Arabic & Urdu RTL Layout",
                    description: "Full right-to-left layout support for Arabic and Urdu. The entire interface mirrors gracefully, including the home screen, settings, and onboarding.",
                    icon: "text.alignright"
                ),
            ]
        }
    }
}
