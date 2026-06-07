import CoreLocation

enum LocationError: Error, Equatable {
    case denied
    case unavailable
    case failed(String)
}

protocol LocationProvider {
    @MainActor
    func requestCurrentLocation() async -> Result<ScheduleLocation, LocationError>
}

@MainActor
final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Result<ScheduleLocation, LocationError>, Never>?

    func requestCurrentLocation() async -> Result<ScheduleLocation, LocationError> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            switch manager.authorizationStatus {
            case .denied, .restricted:
                finish(.failure(.denied))
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            default:
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch self.manager.authorizationStatus {
            case .authorized, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                finish(.failure(.denied))
            case .notDetermined:
                break
            @unknown default:
                finish(.failure(.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            finish(.success(ScheduleLocation(
                label: "Current location",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(.failure(.failed(error.localizedDescription)))
        }
    }

    private func finish(_ result: Result<ScheduleLocation, LocationError>) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
