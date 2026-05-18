import Foundation
import UIKit

/// Central place for support email address and `mailto:` URLs with pre-filled templates.
enum MasjidlySupportMail {
    static let recipient = "mikhailbuilds@gmail.com"

    enum Category {
        case feedback
        case prayerTimes

        func subject(locale: Locale) -> String {
            switch self {
            case .feedback:
                LS("support.mail.feedback.subject", locale: locale)
            case .prayerTimes:
                LS("support.mail.prayer_times.subject", locale: locale)
            }
        }

        func bodyTemplate(locale: Locale) -> String {
            switch self {
            case .feedback:
                LS("support.mail.feedback.body", locale: locale)
            case .prayerTimes:
                LS("support.mail.prayer_times.body", locale: locale)
            }
        }
    }

    struct Context: Sendable {
        var mosqueName: String?
        var appMarketingVersion: String
        var appBuild: String
        var systemVersion: String
    }

    static func mailtoURL(category: Category, locale: Locale, context: Context) -> URL? {
        let footer = LS("support.mail.footer", locale: locale)
        let mosqueLine: String
        if let name = context.mosqueName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let format = LS("support.mail.footer.mosque_line", locale: locale)
            mosqueLine = String(format: format, locale: locale, arguments: [name])
        } else {
            mosqueLine = ""
        }
        let deviceBlock = String(
            format: footer,
            locale: locale,
            arguments: [
                context.appMarketingVersion,
                context.appBuild,
                context.systemVersion,
            ]
        )
        let body = category.bodyTemplate(locale: locale)
            + (mosqueLine.isEmpty ? "" : "\n\n" + mosqueLine)
            + "\n\n"
            + deviceBlock

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: category.subject(locale: locale)),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    static func currentContext(mosqueName: String?) -> Context {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketing = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info["CFBundleVersion"] as? String) ?? "?"
        let system = UIDevice.current.systemVersion
        return Context(
            mosqueName: mosqueName,
            appMarketingVersion: marketing,
            appBuild: build,
            systemVersion: system
        )
    }

    private static func LS(_ key: String, locale: Locale) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}
