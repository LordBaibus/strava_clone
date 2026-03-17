import 'dart:convert';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

dynamic deepFix(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), deepFix(val)));
  }
  if (v is List) return v.map(deepFix).toList();
  return v;
}

Map<String, dynamic> deepMap(dynamic raw) {
  final fixed = deepFix(raw);
  return Map<String, dynamic>.from(fixed as Map);
}


Future<List<Map<String, dynamic>>> fetchLocationSuggestions(String query) async {
  final url =
  Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');
  final response = await http.get(url, headers: {'User-Agent': 'flutter_map_app'});
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => {
      'name': e['display_name'],
      'lat': double.parse(e['lat']),
      'lng': double.parse(e['lon']),
    }).toList();
  }
  return [];
}

Future<LatLng> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return LatLng(40.7128, -74.0060); // fallback location
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return LatLng(40.7128, -74.0060); // fallback
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return LatLng(40.7128, -74.0060); // fallback
  }

  final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return LatLng(position.latitude, position.longitude);
}

Future<LatLng?> getCoordinatesFromLocation(String location) async {
  try {
    final locations = await geo.locationFromAddress(location);
    if (locations.isNotEmpty) {
      final first = locations.first;
      return LatLng(first.latitude, first.longitude);
    }
  } catch (e) {
    print("Error getting coordinates: $e");
  }
  return null;
}

