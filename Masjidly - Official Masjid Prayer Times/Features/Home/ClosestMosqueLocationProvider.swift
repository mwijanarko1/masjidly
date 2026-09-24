import CoreLocation
import Foundation
import Observation

/// One-shot location helper for closest-mosque checks (Settings row + home prompt + onboarding).
@Observable
@MainActor
final class ClosestMosqueLocationProvider: NSObject {
    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// Bumped when a When-In-Use request leaves `.notDetermined` (grant, deny, or restricted).
    private(set) var authorizationDecisionEpoch: Int = 0
    private var isRequestingAuthorization = false

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 250
    }

    func start() {
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined, .denied, .restricted:
            currentLocation = nil
        @unknown default:
            currentLocation = nil
        }
    }

    /// Prompts for When In Use if needed, then fetches a one-shot location when authorized.
    /// Returns `true` if a system prompt was shown (still `.notDetermined` after the call).
    @discardableResult
    func requestWhenInUseAuthorizationIfNeeded() -> Bool {
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            isRequestingAuthorization = true
            locationManager.requestWhenInUseAuthorization()
            return true
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
            return false
        case .denied, .restricted:
            currentLocation = nil
            return false
        @unknown default:
            currentLocation = nil
            return false
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func clear() {
        currentLocation = nil
    }
}

extension ClosestMosqueLocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let previous = authorizationStatus
        authorizationStatus = manager.authorizationStatus

        if isRequestingAuthorization, previous == .notDetermined, authorizationStatus != .notDetermined {
            isRequestingAuthorization = false
            authorizationDecisionEpoch &+= 1
        }

        if isAuthorized {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentLocation = nil
    }
}
