import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../models/geocode_result.dart';

class LocationService {
  LocationService._();

  static final ApiClient _api = ApiClient();

  static Future<GeocodeResult?> getCurrentLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition();

      final response = await _api.reverseGeocode(
        lat: position.latitude,
        lon: position.longitude,
      );

      return GeocodeResult.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
