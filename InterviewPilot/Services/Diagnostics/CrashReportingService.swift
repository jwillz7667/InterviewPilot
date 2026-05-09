import Foundation
import Sentry

/// Wraps Sentry-Cocoa with an interface our code can use without leaking
/// the dependency throughout the app. Initialization is deferred until the
/// backend's /config endpoint hands us a DSN — we never ship a hardcoded one.
enum CrashReportingService {
    enum BreadcrumbLevel {
        case debug, info, warning, error, fatal

        fileprivate var sentryLevel: SentryLevel {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .warning
            case .error: return .error
            case .fatal: return .fatal
            }
        }
    }

    private static var started = false

    static func start(dsn: String, environment: String, tracesSampleRate: Double) {
        guard !started else { return }
        started = true

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.tracesSampleRate = NSNumber(value: tracesSampleRate)
            options.attachScreenshot = false
            options.attachViewHierarchy = true
            options.enableAutoPerformanceTracing = true
            options.enableSwizzling = true
            options.beforeSend = { event in
                // Strip email PII before transport. We only need user.id for
                // crash triage; email lives in the backend logs anyway.
                if let user = event.user {
                    user.email = nil
                    event.user = user
                }
                return event
            }
        }
    }

    static func setUserId(_ userId: String?) {
        guard started else { return }
        if let userId {
            let user = User(userId: userId)
            SentrySDK.setUser(user)
        } else {
            SentrySDK.setUser(nil)
        }
    }

    /// Adds a breadcrumb at one of the boundaries the plan called out:
    /// audio session start, Deepgram WS open/close, OpenAI request/response,
    /// billing claim-access result.
    static func breadcrumb(
        category: String,
        message: String,
        level: BreadcrumbLevel = .info,
        data: [String: Any]? = nil
    ) {
        guard started else { return }
        let crumb = Breadcrumb(level: level.sentryLevel, category: category)
        crumb.message = message
        if let data { crumb.data = data }
        SentrySDK.addBreadcrumb(crumb)
    }

    static func capture(_ error: Error) {
        guard started else { return }
        SentrySDK.capture(error: error)
    }
}
