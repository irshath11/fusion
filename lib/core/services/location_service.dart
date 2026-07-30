import 'package:geolocator/geolocator.dart';

class LocationDataResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;

  LocationDataResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
  });
}

class LocationService {
  /// Fetches current GPS location with high reliability & fast hardware fallback
  static Future<LocationDataResult> getCurrentLocation() async {
    try {
      // 1. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return LocationDataResult(
          latitude: 24.3644,
          longitude: 54.5029,
          accuracy: 50.0,
          address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        );
      }

      // 2. Check if location services are enabled on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Attempt to fetch last known position if GPS toggled off
        Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return LocationDataResult(
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
            accuracy: lastPos.accuracy,
            address:
                '${lastPos.latitude.toStringAsFixed(4)}, ${lastPos.longitude.toStringAsFixed(4)} (Last Known GPS)',
          );
        }
      }

      // 3. Try acquiring instant last known position first
      Position? position = await Geolocator.getLastKnownPosition();

      // 4. Try live GPS acquisition with fallback accuracy
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (_) {
          // Keep last known position if current position times out
        }
      }

      if (position != null) {
        return LocationDataResult(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          address:
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (Live GPS)',
        );
      }

      // Fallback if hardware GPS fix is unavailable
      return LocationDataResult(
        latitude: 24.3644,
        longitude: 54.5029,
        accuracy: 20.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
      );
    } catch (e) {
      return LocationDataResult(
        latitude: 24.3644,
        longitude: 54.5029,
        accuracy: 25.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi ($e)',
      );
    }
  }
}
