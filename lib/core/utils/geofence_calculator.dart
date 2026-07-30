import 'dart:math' as math;

class GeofenceCalculator {
  /// Calculates distance in meters between two GPS coordinates using the Haversine formula.
  static double calculateDistanceInMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadiusMeters = 6371000.0; // Earth's mean radius in meters

    double dLat = _degreesToRadians(endLat - startLat);
    double dLng = _degreesToRadians(endLng - startLng);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Verifies if user GPS location is inside allowed geofence radius.
  static bool isWithinGeofence({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) {
    double distance = calculateDistanceInMeters(userLat, userLng, targetLat, targetLng);
    return distance <= radiusMeters;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
