import CoreLocation
import Foundation
import Observation

enum QiblaDirectionCalculator {
    private static let kaabaLatitude = 21.4225
    private static let kaabaLongitude = 39.8262

    static func indicatorRotationDegrees(qiblaBearing: Double, heading: Double?) -> Double {
        normalizeDegrees(qiblaBearing - (heading ?? 0))
    }

    static func continuousRotationDegrees(previous: Double?, target: Double) -> Double {
        guard let previous else { return target }

        let delta = normalizeDegrees(target - previous + 180) - 180
        return previous + delta
    }

    static func bearingDegrees(fromLatitude latitude: Double, longitude: Double) -> Double {
        let startLatitude = latitude.degreesToRadians
        let startLongitude = longitude.degreesToRadians
        let destinationLatitude = kaabaLatitude.degreesToRadians
        let destinationLongitude = kaabaLongitude.degreesToRadians
        let longitudeDelta = destinationLongitude - startLongitude

        let y = sin(longitudeDelta)
        let x = cos(startLatitude) * tan(destinationLatitude) - sin(startLatitude) * cos(longitudeDelta)

        return normalizeDegrees(atan2(y, x).radiansToDegrees)
    }

    private static func normalizeDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}

@Observable
@MainActor
final class QiblaDirectionProvider: NSObject {
    private let locationManager = CLLocationManager()

    private var currentLocation: CLLocation?
    private var fallbackMosque: Mosque?
    private var headingDegrees: CLLocationDirection?

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var displayedRotationDegrees: Double?

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 250
    }

    func start(fallbackMosque: Mosque?, deferAuthorization: Bool = false) {
        self.fallbackMosque = fallbackMosque
        authorizationStatus = locationManager.authorizationStatus
        updateDisplayedRotation()

        let status = authorizationStatus
        if status == .notDetermined, deferAuthorization {
            // Will be requested later via requestWhenInUseAuthorizationIfNeeded()
        } else {
            switch status {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            case .denied, .restricted:
                break
            @unknown default:
                break
            }
        }

        if CLLocationManager.headingAvailable() {
            locationManager.headingFilter = 1
            locationManager.startUpdatingHeading()
        }
    }

    /// Requests location permission if still `.notDetermined`. Safe to call multiple times.
    func requestWhenInUseAuthorizationIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        currentLocation = nil
        headingDegrees = nil
        displayedRotationDegrees = nil
    }

    func updateFallbackMosque(_ mosque: Mosque?) {
        fallbackMosque = mosque
        updateDisplayedRotation()
    }

    private func updateDisplayedRotation() {
        guard let coordinates = currentCoordinates else { return }

        let bearing = QiblaDirectionCalculator.bearingDegrees(
            fromLatitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        let targetRotation = QiblaDirectionCalculator.indicatorRotationDegrees(
            qiblaBearing: bearing,
            heading: headingDegrees
        )
        let continuousRotation = QiblaDirectionCalculator.continuousRotationDegrees(
            previous: displayedRotationDegrees,
            target: targetRotation
        )

        guard let displayedRotationDegrees else {
            self.displayedRotationDegrees = continuousRotation
            return
        }

        if abs(continuousRotation - displayedRotationDegrees) >= 0.5 {
            self.displayedRotationDegrees = continuousRotation
        }
    }

    private var currentCoordinates: (latitude: Double, longitude: Double)? {
        if let currentLocation {
            return (currentLocation.coordinate.latitude, currentLocation.coordinate.longitude)
        }

        guard let fallbackMosque else { return nil }
        return (fallbackMosque.lat, fallbackMosque.lng)
    }
}

extension QiblaDirectionProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
        updateDisplayedRotation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        updateDisplayedRotation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        updateDisplayedRotation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentLocation = nil
        updateDisplayedRotation()
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}
