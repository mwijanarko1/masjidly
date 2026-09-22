import CoreLocation
import Foundation
import Observation

/// One-shot location helper for closest-mosque checks (Settings row + home prompt).
@Observable
@MainActor
final class ClosestMosqueLocationProvider: NSObject {
    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 250
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined, .denied, .restricted:
            currentLocation = nil
        @unknown default:
            currentLocation = nil
        }
    }

    func clear() {
        currentLocation = nil
    }
}

extension ClosestMosqueLocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
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
