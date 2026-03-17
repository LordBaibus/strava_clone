import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'app_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MapType { standard, satellite }

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  LatLng? currentLocation;
  MapType currentMapType = MapType.satellite;
  Timer? _debounce;

  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await getCurrentLocation();
    setState(() => currentLocation = loc);
    mapController.move(loc, 16);
  }

  void _toggleMapType() {
    setState(() {
      currentMapType =
      currentMapType == MapType.satellite ? MapType.standard : MapType.satellite;
    });
  }

  Future<void> _backToCurrentLocation({double zoom = 20}) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final live = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() => currentLocation = live);
      mapController.move(live, zoom);
    } catch (e) {
      debugPrint("Failed to get current location: $e");
    }
  }

  // ---------------- Search Handling ----------------
  Future<void> _onSearchChanged(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => searchResults = []);
        return;
      }

      try {
        final results = await fetchLocationSuggestions(query);
        setState(() => searchResults = results);
      } catch (e) {
        setState(() => searchResults = []);
      }
    });
  }

  void _onSearchSelected(Map<String, dynamic> result) {
    final target = LatLng(result['lat'], result['lng']);
    mapController.move(target, 16);
    setState(() {
      searchResults = [];
      searchController.clear();
    });
  }

  // ---------------- Tile Layers ----------------
  List<Widget> _buildTileLayers() {
    if (currentMapType == MapType.standard) {
      return [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: "com.jai.strava_clone",
        ),
      ];
    } else {
      return [
        TileLayer(
          urlTemplate:
          "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.jai.strava_clone",
        ),
        TileLayer(
          urlTemplate:
          "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.jai.strava_clone",
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ---------- Search Bar ----------
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: searchController,
                placeholder: "Search location",
                onChanged: _onSearchChanged,
              ),
            ),

            // ---------- Map ----------
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation!,
                      initialZoom: 16,
                      minZoom: 1,
                      maxZoom: 20,
                    ),
                    children: [
                      ..._buildTileLayers(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLocation!,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: CupertinoColors.white,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating search results
                  if (searchResults.isNotEmpty)
                    Positioned(
                      top: 70, // distance from top of the map
                      left: 10,
                      right: 10,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: searchResults.map((res) {
                            return GestureDetector(
                              onTap: () => _onSearchSelected(res),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white.withOpacity(0.7), // transparency
                                  borderRadius: BorderRadius.circular(30), // capsule shape
                                ),
                                child: Text(
                                  res['name'],
                                  style: const TextStyle(
                                    color: CupertinoColors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  // ---------- Map Type Button ----------
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: _floatingButton(
                      icon: CupertinoIcons.layers,
                      onTap: _toggleMapType,
                    ),
                  ),

                  // ---------- Back to Current Location Button ----------
                  Positioned(
                    bottom: 90,
                    right: 20,
                    child: _floatingButton(
                      icon: Icons.gps_fixed_outlined,
                      onTap: _backToCurrentLocation,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: CupertinoColors.black.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: CupertinoColors.white),
      ),
    );
  }
}
