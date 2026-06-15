import Foundation
import WatchConnectivity

/// Sends the latest prayer snapshot to the paired Apple Watch.
///
/// The iOS widget snapshot is persisted in an App Group, but App Groups are not shared
/// across devices. WatchConnectivity mirrors the compact snapshot to watchOS whenever
/// the app starts or refreshes prayer data.
final class WatchPrayerSnapshotTransferService: NSObject, WCSessionDelegate {
    static let shared = WatchPrayerSnapshotTransferService()

    private let snapshotStore = WidgetPrayerSnapshotStore()
    private let encoder = JSONEncoder()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendLatestSnapshot() {
        guard WCSession.isSupported() else { return }
        guard let data = try? encodedSnapshotData() else { return }

        let context = snapshotContext(data: data)
        let session = WCSession.default

        do {
            try session.updateApplicationContext(context)
        } catch {
            // Best effort: if application context is temporarily unavailable, queue a user info transfer.
            if session.isPaired, session.isWatchAppInstalled {
                session.transferUserInfo(context)
            }
        }
    }

    private func snapshotContext(data: Data) -> [String: Any] {
        [Self.snapshotPayloadKey: data]
    }

    private func encodedSnapshotData() throws -> Data {
        let snapshot = try snapshotStore.readSnapshot()
        return try encoder.encode(snapshot)
    }

    static let snapshotPayloadKey = "widgetPrayerSnapshot.v1.data"
    static let snapshotRequestKey = "widgetPrayerSnapshot.v1.request"

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        sendLatestSnapshot()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[Self.snapshotRequestKey] as? Bool == true else { return }
        sendLatestSnapshot()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message[Self.snapshotRequestKey] as? Bool == true else {
            replyHandler([:])
            return
        }

        if let data = try? encodedSnapshotData() {
            replyHandler(snapshotContext(data: data))
        } else {
            replyHandler([:])
        }
        sendLatestSnapshot()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
