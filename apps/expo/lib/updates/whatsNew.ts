import Constants from "expo-constants";
import type { AppLanguage } from "@/store/settings";

export interface WhatsNewItem {
  title: string;
  description: string;
  icon: "globe" | "rtl" | "theme" | "countdown";
}

export interface WhatsNewCopy {
  title: string;
  versionLabel: string;
  swipeHint: string;
  continueLabel: string;
  items: WhatsNewItem[];
}

function expoVersion(): string {
  return (
    Constants.expoConfig?.version ??
    Constants.manifest2?.extra?.expoClient?.version ??
    Constants.nativeApplicationVersion ??
    "1.0.0"
  );
}

function expoBuild(): string {
  const nativeBuild = Constants.nativeBuildVersion;
  const androidVersionCode = Constants.expoConfig?.android?.versionCode;
  return nativeBuild ?? (androidVersionCode ? String(androidVersionCode) : "1");
}

export function currentMasjidlyVersion(): string {
  return expoVersion();
}

export function currentMasjidlyFullVersion(): string {
  return `${expoVersion()} (${expoBuild()})`;
}

const enItems: WhatsNewItem[] = [
  {
    title: "Adhan & Iqamah Countdown",
    description:
      "See the live countdown to the next adhan on the home screen. Tap the qiblah circle to see countdowns to both adhan and iqamah times.",
    icon: "countdown",
  },
  {
    title: "Custom Prayer Theme",
    description:
      "Choose between Dynamic and Fixed theme modes. Dynamic follows the current prayer time's sky colours; Fixed locks to your favourite prayer theme. Find it in Settings > Theme.",
    icon: "theme",
  },
  {
    title: "Multi-Language Support",
    description:
      "Masjidly now speaks your language. Switch between English, Arabic, Urdu, and Indonesian. Prayer names, settings, notifications, and widgets all adapt instantly.",
    icon: "globe",
  },
  {
    title: "Arabic & Urdu RTL Layout",
    description:
      "Full right-to-left layout support for Arabic and Urdu. The entire interface mirrors gracefully, including the home screen, settings, and onboarding.",
    icon: "rtl",
  },

];

const copies: Record<AppLanguage, WhatsNewCopy> = {
  en: {
    title: "Masjidly Update!",
    versionLabel: "Version %s",
    swipeHint: "Swipe to scroll updates",
    continueLabel: "Continue",
    items: enItems,
  },
  ar: {
    title: "تحديث مسجدلي!",
    versionLabel: "الإصدار %s",
    swipeHint: "اسحب لقراءة التحديثات",
    continueLabel: "متابعة",
    items: [
      { ...enItems[0], title: "عدّاد الأذان والإقامة", description: "شاهد العدّاد المباشر للأذان التالي على الشاشة الرئيسية. اضغط على دائرة القبلة لرؤية عدّادات الأذان والإقامة معاً." },
      { ...enItems[1], title: "ثيم الصلاة المخصص", description: "اختر بين الوضع الديناميكي والثابت. الوضع الديناميكي يتبع ألوان وقت الصلاة الحالي؛ الثابت يثبت على ثيم صلاتك المفضلة. الإعدادات > الثيم." },
      { ...enItems[2], title: "دعم تعدد اللغات", description: "يتحدث مسجدلي الآن بلغتك. بدّل بين الإنجليزية والعربية والأردية والإندونيسية، وستتغير أسماء الصلوات والإعدادات والإشعارات والودجات فوراً." },
      { ...enItems[3], title: "تخطيط عربي وأردي من اليمين إلى اليسار", description: "دعم كامل لاتجاه الواجهة من اليمين إلى اليسار للعربية والأردية، بما يشمل الشاشة الرئيسية والإعدادات والشرح التمهيدي." },

    ],
  },
  ur: {
    title: "مسجدلی اپ ڈیٹ!",
    versionLabel: "ورژن %s",
    swipeHint: "اپ ڈیٹس دیکھنے کے لیے سوائپ کریں",
    continueLabel: "جاری رکھیں",
    items: [
      { ...enItems[0], title: "اذان اور اقامت کاؤنٹ ڈاؤن", description: "ہوم اسکرین پر اگلی اذان کا براہِ راست کاؤنٹ ڈاؤن دیکھیں۔ اذان اور اقامت دونوں کے کاؤنٹ ڈاؤن دیکھنے کے لیے قبلہ سرکل کو دبائیں۔" },
      { ...enItems[1], title: "اپنی مرضی کا نماز تھیم", description: "ڈائنامک اور فکسڈ تھیم میں سے انتخاب کریں۔ ڈائنامک موجودہ نماز کے وقت کے رنگوں کی پیروی کرتا ہے؛ فکسڈ آپ کے پسندیدہ نماز تھیم کو مقفل کرتا ہے۔ ترتیبات > تھیم۔" },
      { ...enItems[2], title: "کئی زبانوں کی سہولت", description: "مسجدلی اب آپ کی زبان بولتا ہے۔ انگریزی، عربی، اردو اور انڈونیشیائی میں تبدیلی کریں؛ نمازوں کے نام، ترتیبات، اطلاعات اور وجٹس فوراً بدل جاتے ہیں۔" },
      { ...enItems[3], title: "عربی اور اردو RTL لے آؤٹ", description: "عربی اور اردو کے لیے دائیں سے بائیں مکمل لے آؤٹ، جس میں ہوم اسکرین، ترتیبات اور آن بورڈنگ خوبصورتی سے شامل ہیں۔" },

    ],
  },
  id: {
    title: "Pembaruan Masjidly!",
    versionLabel: "Versi %s",
    swipeHint: "Geser untuk melihat pembaruan",
    continueLabel: "Lanjut",
    items: [
      { ...enItems[0], title: "Hitung Mundur Adzan & Iqamah", description: "Lihat hitung mundur langsung ke adzan berikutnya di layar utama. Ketuk lingkaran qiblah untuk melihat hitung mundur ke waktu adzan dan iqamah." },
      { ...enItems[1], title: "Tema Salat Kustom", description: "Pilih antara mode Dinamis dan Tetap. Dinamis mengikuti warna langit waktu salat saat ini; Tetap mengunci ke tema salat favorit Anda. Pengaturan > Tema." },
      { ...enItems[2], title: "Dukungan Banyak Bahasa", description: "Masjidly kini berbicara dalam bahasa Anda. Beralih antara Inggris, Arab, Urdu, dan Indonesia; nama salat, pengaturan, notifikasi, dan widget langsung menyesuaikan." },
      { ...enItems[3], title: "Tata Letak RTL Arab & Urdu", description: "Dukungan penuh kanan-ke-kiri untuk Arab dan Urdu, termasuk layar utama, pengaturan, dan onboarding." },

    ],
  },
};

export function whatsNewCopy(language: AppLanguage): WhatsNewCopy {
  return copies[language] ?? copies.en;
}
