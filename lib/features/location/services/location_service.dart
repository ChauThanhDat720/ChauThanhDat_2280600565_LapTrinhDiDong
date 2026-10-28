import 'package:geolocator/geolocator.dart';

import '../domain/patient_location.dart';

class LocationService {
  const LocationService();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<PatientLocation> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return PatientLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }

  /// Luồng cập nhật vị trí thời gian thực (Real-time GPS Location Stream)
  Stream<PatientLocation> getPositionStream({
    int distanceFilter = 1,
    Duration interval = const Duration(seconds: 2),
  }) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      timeLimit: null,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (position) => PatientLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
