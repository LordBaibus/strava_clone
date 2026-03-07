import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'record.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_min_gpl/return_code.dart';

dynamic _deepFix(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), _deepFix(val)));
  }
  if (v is List) return v.map(_deepFix).toList();
  return v;
}

Map<String, dynamic> _deepMap(dynamic raw) {
  final fixed = _deepFix(raw);
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('activities'); // where route will be saved
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en', 'US'),
      ],
      home: MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            // RECORD BUTTON
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const RecordPage(), // from record.dart
              ),
            );
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.home),label: "Home",),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.map),label: "Maps",),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.circle),label: "Record",),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2),label: "Groups",),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person),label: "You",),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const Home();
          case 1:
            return const MapScreen();
          case 3:
            return const Groups();
          case 4:
            return const You();
          default:
            return const Home(); // index 2 never used
        }
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<LatLng> route1 = [
    LatLng(25.2048, 55.2708),
    LatLng(25.2100, 55.2800),
    LatLng(25.2200, 55.2900),
  ];
  List<LatLng> route2 = [
    LatLng(40.7128, -74.0060),
    LatLng(40.7150, -74.0100),
    LatLng(40.7180, -74.0150),
  ];
  List<LatLng> route3 = [
    LatLng(40.7128, -74.0060),
    LatLng(40.7150, -74.0100),
    LatLng(40.7180, -74.0150),
  ];
  List<LatLng> route4 = [
    LatLng(46.220859, 6.100466),
    LatLng(46.251374, 6.138747),
    LatLng(46.346017, 6.167929),
  ];
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ActivityPostCard(
              name: "TJ Enriquez",
              location: "Downtown Dubai, United Arab Emirates",
              distance: "19.39 km",
              pace: "6:38 /km",
              achievements: 30,
              kudos: 995,
              comments: 2,
              route: route1,
              profileImage: "assets/profile1.jpg",
              caption:"Towards the goal of being The Biggest Loser. I can do this!"
            ),
            const SizedBox(height: 20),
            ActivityPostCard(
              name: "Desmer Sison",
              location: "Central Park, New York",
              distance: "10.12 km",
              pace: "5:02 /km",
              achievements: 42,
              kudos: 420,
              comments: 8,
              route: route2,
              profileImage: "assets/profile2.jpg",
              caption: "Accidentally set a PR because I saw my ex at mile 2. Powered by unresolved feelings.",
            ),
            const SizedBox(height: 20),
            ActivityPostCard(
              name: "Jhanelle Delos Santos",
              location: "Moscow, Russia",
              distance: "5.5 km",
              pace: "8:38 /km",
              achievements: 22,
              kudos: 4000,
              comments: 120,
              route: route3,
              profileImage: "assets/profile3.jpg",
              caption: "Not me accidentally breaking the algorithm on my morning ‘mental health’ run 💅✨ Just out here healing, glowing, and pretending I didn’t check who viewed my story mid-stride. Cardio but make it main character energy.",
            ),
            const SizedBox(height: 20),
            ActivityPostCard(
              name: "Lord Baibus",
              location: "Geneva Switzerland",
              distance: "45.80 km",
              pace: "4:20 /km",
              achievements: 99,
              kudos: 67676,
              comments: 69420,
              route: route4,
              profileImage: "assets/profile4.jpg",
              caption: "Went for a quick run. If you think you saw me, no you didn’t. 🕶️"
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}


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

class Summary extends StatefulWidget {
  const Summary({super.key});

  @override
  State<Summary> createState() => _SummaryState();
}

class _SummaryState extends State<Summary> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(child: SafeArea(child:
    Column(children: [
      Text("Summary")
    ],)));
  }
}

class Groups extends StatelessWidget {
  const Groups({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _GroupsTopBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    _ActiveGroupsTab(),
                    _ChallengesTab(),
                    _ClubsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsTopBar extends StatelessWidget {
  const _GroupsTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Material(
        color: Colors.transparent,
        child: TabBar(
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(
              color: CupertinoColors.activeOrange,
              width: 3,
            ),
            insets: EdgeInsets.symmetric(horizontal: 24),
          ),
          dividerColor: const Color(0xFF3A3A3A),
          labelColor: CupertinoColors.white,
          unselectedLabelColor: CupertinoColors.systemGrey,
          labelStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            const Tab(text: "Active"),
            const Tab(text: "Challenges"),
            const Tab(text: "Clubs"),
          ],
        ),
      ),
    );
  }
}

class _ActiveGroupsTab extends StatelessWidget {
  const _ActiveGroupsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: const [
        Text(
          "Available challenges",
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 24),

        _ChallengeTile(
          badgeText: "7KM",
          title: "March Cycling\nElevation Challenge",
          description: "Climb a total of 7,000 m (22,965.9 ft)\nin March.",
          dateRange: "Mar 1, 2026 to Mar 31, 2026",
          icon: Icons.directions_bike_outlined,
        ),
        SizedBox(height: 28),

        _ChallengeTile(
          badgeText: "100K",
          title: "March Walk 100K\nSteps Challenge",
          description: "Walk a total of 100,000 steps in March",
          dateRange: "Mar 1, 2026 to Mar 31, 2026",
          icon: Icons.directions_walk_outlined,
        ),
        SizedBox(height: 28),

        _ChallengeTile(
          badgeText: "10h",
          title: "March Flexibility Challenge",
          description: "Complete 10 hours of yoga or workout\nactivity this month",
          dateRange: "Mar 1, 2026 to Mar 31, 2026",
          icon: Icons.self_improvement_outlined,
        ),
      ],
    );
  }
}

class _ChallengesTab extends StatefulWidget {
  const _ChallengesTab();

  @override
  State<_ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<_ChallengesTab> {
  int selectedFilterIndex = 0;

  final List<Map<String, dynamic>> filters = [
    {"label": "Run", "icon": Icons.directions_run_outlined},
    {"label": "Ride", "icon": Icons.directions_bike_outlined},
    {"label": "Swim", "icon": Icons.waves_outlined},
    {"label": "Walk", "icon": Icons.directions_walk_outlined},
  ];

  final List<Map<String, dynamic>> challengeCards = [
    {
      "badge": _ChallengeBadgeStyle(
        type: BadgeType.star,
        text: "400'",
      ),
      "title": "March 400-minute\nx Runna Challenge",
      "desc":
      "Complete 400 minutes of\nactivity in March - any\nactivity counts!",
      "date": "Mar 1 to Mar 31, 2026",
    },
    {
      "badge": _ChallengeBadgeStyle(
        type: BadgeType.imageLike,
        text: "RB",
        bgColor: Color(0xFF1F1F1F),
        textColor: Color(0xFFFFD54F),
      ),
      "title": "Red Bull Jumpstart\nYour Routine",
      "desc": "Move for 15 days",
      "date": "Feb 11 to Mar 10, 2026",
    },
    {
      "badge": _ChallengeBadgeStyle(
        type: BadgeType.circle,
        text: "5\nKM",
        bgColor: Color(0xFFBDBDBD),
        textColor: CupertinoColors.white,
      ),
      "title": "Adizero Feel Fast",
      "desc": "Complete a fast 5K effort",
      "date": "Mar 1 to Mar 31, 2026",
    },
    {
      "badge": _ChallengeBadgeStyle(
        type: BadgeType.circle,
        text: "33.3",
        bgColor: Color(0xFF58D0D0),
        textColor: CupertinoColors.white,
      ),
      "title": "UltraSwim 33.3\nVirtual",
      "desc": "Swim your virtual distance goal",
      "date": "Mar 1 to Mar 31, 2026",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.only(top: 14, bottom: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(filters.length, (index) {
                final item = filters[index];
                final isSelected = selectedFilterIndex == index;

                return Padding(
                  padding: EdgeInsets.only(right: index == filters.length - 1 ? 0 : 12),
                  child: _ChallengeFilterChip(
                    label: item["label"],
                    icon: item["icon"],
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        selectedFilterIndex = index;
                      });
                    },
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF9EABB8),
                    child: Text(
                      "J",
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recommended For You",
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Based on your activities",
                          style: TextStyle(
                            color: CupertinoColors.systemGrey2,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: challengeCards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.60,
                ),
                itemBuilder: (context, index) {
                  final item = challengeCards[index];
                  return _ChallengeCard(
                    badge: item["badge"],
                    title: item["title"],
                    description: item["desc"],
                    dateRange: item["date"],
                    onJoin: () {},
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChallengeFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChallengeFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: CupertinoColors.black,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.white
                : CupertinoColors.systemGrey.withOpacity(0.65),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: CupertinoColors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BadgeType { star, circle, imageLike }

class _ChallengeBadgeStyle {
  final BadgeType type;
  final String text;
  final Color? bgColor;
  final Color? textColor;

  const _ChallengeBadgeStyle({
    required this.type,
    required this.text,
    this.bgColor,
    this.textColor,
  });
}

class _ChallengeCard extends StatelessWidget {
  final _ChallengeBadgeStyle badge;
  final String title;
  final String description;
  final String dateRange;
  final VoidCallback onJoin;

  const _ChallengeCard({
    required this.badge,
    required this.title,
    required this.description,
    required this.dateRange,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChallengeCardBadge(badge: badge),
          const SizedBox(height: 16),

          Text(
            title,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              height: 1.18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: const [
              Icon(
                CupertinoIcons.compass,
                color: CupertinoColors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Icon(
                Icons.grade,
                color: CupertinoColors.white,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            description,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            dateRange,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),

          const Spacer(),

          GestureDetector(
            onTap: onJoin,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: CupertinoColors.activeOrange,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Text(
                  "Join",
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCardBadge extends StatelessWidget {
  final _ChallengeBadgeStyle badge;

  const _ChallengeCardBadge({required this.badge});

  @override
  Widget build(BuildContext context) {
    switch (badge.type) {
      case BadgeType.star:
        return SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: ShapeDecoration(
                  color: const Color(0xFF0C1C28),
                  shape: StarBorder.polygon(
                    sides: 12,
                    pointRounding: 0.25,
                  ),
                  shadows: [
                    BoxShadow(
                      color: const Color(0xFF7EF2FF).withOpacity(0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: ShapeDecoration(
                  color: const Color(0xFF132736),
                  shape: StarBorder.polygon(
                    sides: 12,
                    pointRounding: 0.25,
                    side: const BorderSide(
                      color: Color(0xFF9CF7FF),
                      width: 2.2,
                    ),
                  ),
                ),
              ),
              Text(
                badge.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5FE8FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );

      case BadgeType.circle:
        return Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: badge.bgColor ?? CupertinoColors.systemGrey,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              badge.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: badge.textColor ?? CupertinoColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        );

      case BadgeType.imageLike:
        return Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: badge.bgColor ?? const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              badge.text,
              style: TextStyle(
                color: badge.textColor ?? CupertinoColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
    }
  }
}

class _ClubsTab extends StatelessWidget {
  const _ClubsTab();

  @override
  Widget build(BuildContext context) {
    final clubs = <_ClubData>[
      const _ClubData(
        name: "Clark Runners'\nCommunity",
        location: "Mabalacat, Pampanga,\nPhilippines",
        membersText: "3,146 Runners",
        sportIcon: Icons.directions_run_outlined,
        // Use either imageAsset OR imageUrl
        imageAsset: "assets/clark_runners.jpg",
        // imageUrl: "https://.../clark.png",
      ),
      const _ClubData(
        name: "ANGELENOS\nRUNNERS",
        location: "Angeles, Central Luzon,\nPhilippines",
        membersText: "2,652 Runners",
        sportIcon: Icons.directions_run_outlined,
        imageAsset: "assets/angelenos_runners.jpg",
      ),
      const _ClubData(
        name: "Pampanga\nCycling Mob",
        location: "Pampanga,\nPhilippines",
        membersText: "1,120 Riders",
        sportIcon: Icons.directions_bike_outlined,
        imageAsset: "assets/pampanga_cycling.jpg",
      ),
      const _ClubData(
        name: "Clark Running Club",
        location: "Clark, Pampanga,\nPhilippines",
        membersText: "980 Runners",
        sportIcon: Icons.directions_run_outlined,
        imageAsset: "assets/clark_running_club.jpg",
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      children: [
        // Header row
        Row(
          children: const [
            Icon(
              Icons.gps_fixed_rounded,
              color: CupertinoColors.white,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              "Popular Clubs Near You",
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Grid of club cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clubs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62, // tweak: higher = shorter cards
          ),
          itemBuilder: (context, i) {
            return _ClubCard(
              club: clubs[i],
              onJoin: () {
                // TODO: join logic (Hive, API, etc.)
              },
            );
          },
        ),
      ],
    );
  }
}

class _ClubData {
  final String name;
  final String location;
  final String membersText;
  final IconData sportIcon;

  final String? imageAsset; // preferred if you have local assets
  final String? imageUrl;   // fallback if you want network images

  const _ClubData({
    required this.name,
    required this.location,
    required this.membersText,
    required this.sportIcon,
    this.imageAsset,
    this.imageUrl,
  });
}

class _ClubCard extends StatelessWidget {
  final _ClubData club;
  final VoidCallback onJoin;

  const _ClubCard({
    required this.club,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClubLogo(imageAsset: club.imageAsset, imageUrl: club.imageUrl),
          const SizedBox(height: 14),

          Text(
            club.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),

          Icon(
            club.sportIcon,
            color: CupertinoColors.white,
            size: 26,
          ),
          const SizedBox(height: 10),

          Text(
            club.location,
            style: const TextStyle(
              color: CupertinoColors.systemGrey2,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            club.membersText,
            style: const TextStyle(
              color: CupertinoColors.systemGrey2,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(),

          GestureDetector(
            onTap: onJoin,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: CupertinoColors.activeOrange,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Text(
                  "Join",
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubLogo extends StatelessWidget {
  final String? imageAsset;
  final String? imageUrl;

  const _ClubLogo({this.imageAsset, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final child = () {
      if (imageAsset != null) {
        return Image.asset(imageAsset!, fit: BoxFit.cover);
      }
      if (imageUrl != null) {
        return Image.network(imageUrl!, fit: BoxFit.cover);
      }
      // Placeholder if you haven't added images yet
      return const Center(
        child: Icon(
          Icons.group,
          color: CupertinoColors.white,
          size: 30,
        ),
      );
    }();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 64,
        height: 64,
        color: const Color(0xFF1A1A1C),
        child: child,
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final String badgeText;
  final String title;
  final String description;
  final String dateRange;
  final IconData icon;

  const _ChallengeTile({
    required this.badgeText,
    required this.title,
    required this.description,
    required this.dateRange,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChallengeBadge(text: badgeText),
        const SizedBox(width: 18),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        icon,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 17,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  dateRange,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChallengeBadge extends StatelessWidget {
  final String text;

  const _ChallengeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: ShapeDecoration(
              color: const Color(0xFF0C1C28),
              shape: StarBorder.polygon(
                sides: 12,
                pointRounding: 0.25,
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFF7EF2FF).withOpacity(0.18),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: ShapeDecoration(
              color: const Color(0xFF132736),
              shape: StarBorder.polygon(
                sides: 12,
                pointRounding: 0.25,
                side: const BorderSide(
                  color: Color(0xFF9CF7FF),
                  width: 2.5,
                ),
              ),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF5FE8FF),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class You extends StatefulWidget {
  const You({super.key});

  @override
  State<You> createState() => _YouState();
}

class _YouState extends State<You> {
  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              _YouTopTabs(),
              Expanded(
                child: TabBarView(
                  children: [
                    _ProgressTab(),
                    _ActivitiesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YouTopTabs extends StatelessWidget {
  const _YouTopTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Material(
        color: Colors.transparent,
        child: TabBar(
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(
              color: CupertinoColors.activeOrange,
              width: 3,
            ),
            insets: EdgeInsets.symmetric(horizontal: 24),
          ),
          dividerColor: const Color(0xFF2A2A2A),
          labelColor: CupertinoColors.white,
          unselectedLabelColor: CupertinoColors.systemGrey,
          labelStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: "Progress"),
            Tab(text: "Activities"),
          ],
        ),
      ),
    );
  }
}

class _ActivityMeta {
  final DateTime startedAt;
  final String workoutType;
  final String title;

  const _ActivityMeta({
    required this.startedAt,
    required this.workoutType,
    required this.title,
  });

  DateTime get dateOnly => DateTime(startedAt.year, startedAt.month, startedAt.day);

  int get dayKey => startedAt.year * 10000 + startedAt.month * 100 + startedAt.day;
}

// ===============================
// PROGRESS TAB (AESTHETIC ONLY)
// ===============================
class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0B);
    const card = Color(0xFF111113);
    const card2 = Color(0xFF0F0F11);
    const orange = CupertinoColors.activeOrange;

    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          // Top glow/hero section
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              decoration: BoxDecoration(
                color: bg,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    orange.withOpacity(0.65),
                    bg.withOpacity(1),
                    bg.withOpacity(1),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Unlock your full potential.",
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 36,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Track your progress and reach your goals with\nsubscription features.",
                    style: TextStyle(
                      color: CupertinoColors.systemGrey2,
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Performance Predictions Card
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Performance Predictions",
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "See your projected finish time for your next race.",
                  style: TextStyle(
                    color: CupertinoColors.systemGrey2,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),

                _PredictionRow(
                  badgeText: "5K",
                  time: "28:26",
                  pace: "5:41 /km",
                  delta: "1:40",
                  orange: orange,
                ),
                const SizedBox(height: 16),
                _PredictionRow(
                  badgeText: "10K",
                  time: "1:00:04",
                  pace: "6:00 /km",
                  delta: "1:10",
                  orange: orange,
                  dimmed: true,
                ),

                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.white.withOpacity(0.6),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Best Efforts Card
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Best Efforts",
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),

                _BestEffortRow(
                  primary: "5K PR",
                  secondary: "Mar 7, 2026",
                  rightValue: "26:54",
                  showChevron: false,
                  highlighted: true,
                  orange: orange,
                ),

                const SizedBox(height: 18),

                _BestEffortRow(
                  primary: "2nd-fastest 5K",
                  secondary: "Mar 7, 2025",
                  rightValue: "30:12",
                  showChevron: true,
                  highlighted: false,
                  orange: orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final String badgeText;
  final String time;
  final String pace;
  final String delta;
  final Color orange;
  final bool dimmed;

  const _PredictionRow({
    required this.badgeText,
    required this.time,
    required this.pace,
    required this.delta,
    required this.orange,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final main = dimmed ? CupertinoColors.systemGrey : CupertinoColors.white;
    final sub = dimmed ? CupertinoColors.systemGrey2.withOpacity(0.6) : CupertinoColors.systemGrey2;

    return Row(
      children: [
        _StarBadge(
          text: badgeText,
          orange: orange,
          dimmed: dimmed,
        ),
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: main,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pace,
                style: TextStyle(
                  color: sub,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        _GreenDeltaPill(
          text: delta,
          dimmed: dimmed,
        ),
      ],
    );
  }
}

class _StarBadge extends StatelessWidget {
  final String text;
  final Color orange;
  final bool dimmed;

  const _StarBadge({
    required this.text,
    required this.orange,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final border = dimmed ? orange.withOpacity(0.35) : orange.withOpacity(0.95);
    final txt = dimmed ? orange.withOpacity(0.35) : orange.withOpacity(0.95);

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: ShapeDecoration(
              color: Colors.transparent,
              shape: StarBorder.polygon(
                sides: 12,
                pointRounding: 0.22,
                side: BorderSide(color: border, width: 2.4),
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: txt,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenDeltaPill extends StatelessWidget {
  final String text;
  final bool dimmed;

  const _GreenDeltaPill({required this.text, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    final bg = dimmed ? const Color(0xFF1C2A1A) : const Color(0xFF2E4B2B);
    final fg = dimmed ? const Color(0xFF7FA77A).withOpacity(0.5) : const Color(0xFFBEE8B9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_drop_down, color: fg, size: 22),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestEffortRow extends StatelessWidget {
  final String primary;
  final String secondary;
  final String rightValue;
  final bool showChevron;
  final bool highlighted;
  final Color orange;

  const _BestEffortRow({
    required this.primary,
    required this.secondary,
    required this.rightValue,
    required this.showChevron,
    required this.highlighted,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = highlighted ? CupertinoColors.white : CupertinoColors.systemGrey;
    final subColor = highlighted
        ? CupertinoColors.systemGrey2
        : CupertinoColors.systemGrey2.withOpacity(0.55);
    final rightColor = highlighted ? CupertinoColors.white : CupertinoColors.systemGrey.withOpacity(0.65);

    return Row(
      children: [
        _EffortMedal(highlighted: highlighted),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                secondary,
                style: TextStyle(
                  color: subColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        Text(
          rightValue,
          style: TextStyle(
            color: rightColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        if (showChevron) ...[
          const SizedBox(width: 10),
          Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.white.withOpacity(0.55),
            size: 22,
          ),
        ],
      ],
    );
  }
}

class _EffortMedal extends StatelessWidget {
  final bool highlighted;
  const _EffortMedal({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? const Color(0xFFB68D2C) : const Color(0xFF2A2A2A);
    final fg = highlighted ? CupertinoColors.black : CupertinoColors.systemGrey;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          highlighted ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
          color: fg,
          size: 28,
        ),
      ),
    );
  }
}

class _IndexItem {
  final dynamic hiveKey; // key inside activities_index
  final String activityId;
  final String boxName;
  final String startedAt;

  const _IndexItem({
    required this.hiveKey,
    required this.activityId,
    required this.boxName,
    required this.startedAt,
  });
}

class _LegacyItem {
  final int atIndex; // original index in box
  final Map<String, dynamic> data;

  const _LegacyItem({required this.atIndex, required this.data});
}

class _ActivitiesTab extends StatefulWidget {
  const _ActivitiesTab();

  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  Box? _indexBox;
  Box? _legacyBox;

  // Cache: boxName -> Future of activity data map
  final Map<String, Future<Map<String, dynamic>?>> _activityCache = {};

  @override
  void initState() {
    super.initState();
    _initBoxes();
  }

  Future<void> _initBoxes() async {
    final idx = await Hive.openBox('activities_index');
    final legacy = await Hive.openBox('activities'); // fallback

    if (!mounted) return;
    setState(() {
      _indexBox = idx;
      _legacyBox = legacy;
    });
  }

  Future<Map<String, dynamic>?> _loadActivityDataFromBox(String boxName) {
    return _activityCache.putIfAbsent(boxName, () async {
      final box = await Hive.openBox(boxName);
      final raw = box.get('data');
      if (raw is! Map) return null;
      return _deepMap(raw);
    });
  }

  List<_IndexItem> _readIndexItems(Box box) {
    final out = <_IndexItem>[];

    for (int i = 0; i < box.length; i++) {
      final key = box.keyAt(i);
      final raw = box.get(key);
      if (raw is! Map) continue;

      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as String?) ?? '';
      final bn = (m['box'] as String?) ?? '';
      final startedAt = (m['startedAt'] as String?) ?? '';

      if (id.isEmpty || bn.isEmpty) continue;

      out.add(_IndexItem(
        hiveKey: key,
        activityId: id,
        boxName: bn,
        startedAt: startedAt,
      ));
    }

    out.sort((a, b) => b.startedAt.compareTo(a.startedAt)); // newest first
    return out;
  }

  List<_LegacyItem> _readLegacyItems(Box box) {
    final out = <_LegacyItem>[];
    for (int i = 0; i < box.length; i++) {
      final raw = box.getAt(i);
      if (raw is! Map) continue;
      out.add(_LegacyItem(atIndex: i, data: _deepMap(raw)));
    }

    out.sort((a, b) {
      final da = (a.data['startedAt'] ?? '') as String;
      final db = (b.data['startedAt'] ?? '') as String;
      return db.compareTo(da);
    });
    return out;
  }

  Future<void> _deleteIndexActivity(_IndexItem item) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Delete activity permanently?"),
        content: const Text("This will remove the activity from your device."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final idx = _indexBox;
    if (idx == null) return;

    // 1) remove from activities_index
    await idx.delete(item.hiveKey);

    // 2) delete per-activity box from disk
    try {
      if (Hive.isBoxOpen(item.boxName)) {
        await Hive.box(item.boxName).close();
      }
      await Hive.deleteBoxFromDisk(item.boxName);
    } catch (_) {}

    // 3) delete activity files folder (media, etc.)
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory("${docs.path}/activities/${item.activityId}");
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}

    // 4) clear cache for this box
    _activityCache.remove(item.boxName);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteLegacyActivity(_LegacyItem item) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Delete activity permanently?"),
        content: const Text("This will remove the activity from your device."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final legacy = _legacyBox;
    if (legacy == null) return;
    await legacy.deleteAt(item.atIndex);

    if (!mounted) return;
    setState(() {});
  }

  void _openShare(Map<String, dynamic> activity) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => SharePage(activity: activity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexBox;
    final legacy = _legacyBox;

    if (idx == null || legacy == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final useIndex = idx.isNotEmpty;
    final listenable = (useIndex ? idx : legacy).listenable();

    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, _, __) {
        if (useIndex) {
          final items = _readIndexItems(idx);

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No activities yet",
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _loadActivityDataFromBox(it.boxName),
                builder: (context, snap) {
                  final data = snap.data;
                  if (data == null) return _ActivitySkeleton();

                  return _ActivityFeedCard(
                    activity: data,
                    onShare: () => _openShare(data),
                    onDelete: () => _deleteIndexActivity(it),
                  );
                },
              );
            },
          );
        } else {
          final items = _readLegacyItems(legacy);

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No activities yet",
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final data = it.data;

              return _ActivityFeedCard(
                activity: data,
                onShare: () => _openShare(data),
                onDelete: () => _deleteLegacyActivity(it),
              );
            },
          );
        }
      },
    );
  }
}

/* =========================
   ACTIVITY FEED CARD (UI)
   ========================= */

class _ActivityFeedCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _ActivityFeedCard({
    required this.activity,
    required this.onShare,
    required this.onDelete,
  });

  String _formatHeaderDate(String? iso) {
    if (iso == null || iso.isEmpty) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat("MMMM d, y 'at' h:mm a").format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return "${seconds}s";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return "${m}m ${s.toString().padLeft(2, '0')}s";
    final h = m ~/ 60;
    final mm = m % 60;
    return "${h}h ${mm}m";
  }

  String _avgPaceFromData(Map<String, dynamic> a) {
    final pace = a['avgPace'];
    if (pace is String && pace.isNotEmpty) return pace;

    final dist = (a['distanceKm'] is num) ? (a['distanceKm'] as num).toDouble() : 0.0;
    final secs = (a['durationSeconds'] is int) ? a['durationSeconds'] as int : 0;
    if (dist <= 0 || secs <= 0) return "-:--";

    final minPerKm = (secs / 60.0) / dist;
    int mins = minPerKm.floor();
    int s = ((minPerKm - mins) * 60).round();
    if (s == 60) { mins += 1; s = 0; }
    return "$mins:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0B);

    final title = (activity['title'] as String?)?.trim();
    final workoutType = (activity['workoutType'] as String?) ?? "Run";
    final startedAt = (activity['startedAt'] as String?) ?? "";

    final durationSeconds = (activity['durationSeconds'] is int) ? activity['durationSeconds'] as int : 0;
    final distanceKm = (activity['distanceKm'] is num) ? (activity['distanceKm'] as num).toDouble() : 0.0;
    final avgPace = _avgPaceFromData(activity);

    final mediaRaw = activity['media'];
    final media = <Map<String, dynamic>>[];

    if (mediaRaw is List) {
      for (final e in mediaRaw) {
        if (e is Map) {
          media.add(Map<String, dynamic>.from(e)); // converts _Map<dynamic,dynamic>
        }
      }
    }

    final routeRaw = (activity['route'] is List) ? List.from(activity['route']) : const [];
    final route = <LatLng>[];
    for (final p in routeRaw) {
      if (p is List && p.length >= 2) {
        route.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (+ actions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF8FA2AE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    "J",
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Jairus Maniago",
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatHeaderDate(startedAt)} · Strava App",
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.directions_run_outlined, color: CupertinoColors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Pampanga",
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Share + Delete buttons
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                minSize: 0,
                onPressed: onShare,
                child: const Icon(CupertinoIcons.share, color: CupertinoColors.white, size: 22),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                minSize: 0,
                onPressed: onDelete,
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white, size: 22),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            (title == null || title.isEmpty) ? workoutType : title,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 44,
              height: 1.02,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              _InfoStat(label: "Time", value: _formatTime(durationSeconds)),
              const SizedBox(width: 28),
              _InfoStat(label: "Avg. Pace (/km)", value: avgPace),
              const SizedBox(width: 28),
              _InfoStat(label: "Distance (km)", value: distanceKm.toStringAsFixed(2)),
            ],
          ),

          const SizedBox(height: 18),

          _MediaCarousel(route: route, media: media),
        ],
      ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  final String label;
  final String value;
  const _InfoStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/* =========================
   CAROUSEL (Route + Media)
   ========================= */

class _MediaCarousel extends StatefulWidget {
  final List<LatLng> route;
  final List<Map<String, dynamic>> media;

  const _MediaCarousel({
    required this.route,
    required this.media,
  });

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  late final PageController _pc;
  int _index = 0;

  int get _count => 1 + widget.media.length; // 1st page = route map

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pc,
            itemCount: _count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              // page 0: route map
              if (i == 0) {
                return _CarouselCard(
                  child: _RoutePreviewMap(route: widget.route),
                );
              }

              // media pages
              final item = widget.media[i - 1];
              final type = (item['type'] as String?) ?? "image";
              final path = (item['path'] as String?) ?? "";

              if (type == "video") {
                return _CarouselCard(
                  child: _VideoSlide(path: path),
                );
              }

              return _CarouselCard(
                child: _ImageSlide(path: path),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_count, (i) {
            final active = i == _index;
            return Container(
              width: active ? 8 : 6,
              height: active ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: active
                    ? CupertinoColors.activeOrange
                    : CupertinoColors.systemGrey.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final Widget child;
  const _CarouselCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color(0xFF1A1A1C),
          child: child,
        ),
      ),
    );
  }
}

class _ImageSlide extends StatelessWidget {
  final String path;
  const _ImageSlide({required this.path});

  @override
  Widget build(BuildContext context) {
    final f = File(path);
    if (!f.existsSync()) {
      return const Center(
        child: Text(
          "Image not found",
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
        ),
      );
    }
    return Image.file(f, fit: BoxFit.cover);
  }
}

class _VideoSlide extends StatefulWidget {
  final String path;
  const _VideoSlide({super.key, required this.path});

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final file = File(widget.path);
      if (!file.existsSync()) {
        setState(() => _hasError = true);
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(true);

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      debugPrint("Video init error: $e");
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Text(
          "Video not found or failed to load",
          style: TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 16,
          ),
        ),
      );
    }

    if (!_isReady || _controller == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (!_controller!.value.isPlaying)
            const Icon(
              CupertinoIcons.play_circle_fill,
              color: CupertinoColors.white,
              size: 72,
            ),
        ],
      ),
    );
  }
}

/* =========================
   ROUTE MAP SLIDE
   ========================= */

class _RoutePreviewMap extends StatefulWidget {
  final List<LatLng> route;
  const _RoutePreviewMap({required this.route});

  @override
  State<_RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<_RoutePreviewMap> {
  final MapController _mc = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    if (widget.route.length < 2) return;
    final b = LatLngBounds.fromPoints(widget.route);
    _mc.fitCamera(
      CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route.isEmpty) {
      return const Center(
        child: Text(
          "No route",
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
        ),
      );
    }

    return FlutterMap(
      mapController: _mc,
      options: MapOptions(
        initialCenter: widget.route.first,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate:
          "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.jai.strava_clone",
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.route,
              strokeWidth: 5,
              color: CupertinoColors.activeOrange,
            ),
          ],
        ),
      ],
    );
  }
}

/* =========================
   SIMPLE SKELETON
   ========================= */

class _ActivitySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 520,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}

class ActivityPostCard extends StatelessWidget {
  final String name;
  final String location;
  final String distance;
  final String pace;
  final int kudos;
  final int comments;
  final List<LatLng> route;
  final String profileImage;
  final String caption;
  final int achievements;

  const ActivityPostCard({
    super.key,
    required this.name,
    required this.location,
    required this.distance,
    required this.pace,
    required this.kudos,
    required this.comments,
    required this.route,
    required this.profileImage,
    required this.caption,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: CupertinoColors.systemGrey,
                  backgroundImage: AssetImage(profileImage),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      location,
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // TITLE
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              caption,
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // STATS ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(title: "Distance", value: distance),
                _StatItem(title: "Pace", value: pace),
                _StatItem(title: "Achievements", value: achievements.toString()),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // MAP PREVIEW
          SizedBox(
            height: 550,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: route.first,
                initialZoom: 13,
                interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                  userAgentPackageName: "com.jai.strava_clone",
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 4,
                      color: CupertinoColors.activeOrange,
                    )
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // INTERACTION ROW
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$kudos gave kudos",
                  style: const TextStyle(
                      color: CupertinoColors.systemGrey),
                ),
                Text(
                  "$comments comments",
                  style: const TextStyle(
                      color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _StatItem extends StatelessWidget {
  final String title;
  final String value;

  const _StatItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class SharePage extends StatefulWidget {
  final Map<String, dynamic> activity;
  const SharePage({super.key, required this.activity});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final ImagePicker _picker = ImagePicker();

  File? _bgImage;
  File? _bgVideo;
  VideoPlayerController? _videoCtrl;

  final GlobalKey _fullPreviewKey = GlobalKey();
  final GlobalKey _overlayOnlyKey = GlobalKey();

  late final double _distanceKm;
  late final String _avgPace;
  late final String _timeText;
  late final List<LatLng> _route;

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();

    _distanceKm = (widget.activity['distanceKm'] is num)
        ? (widget.activity['distanceKm'] as num).toDouble()
        : 0.0;

    _avgPace = (widget.activity['avgPace'] is String &&
        (widget.activity['avgPace'] as String).isNotEmpty)
        ? widget.activity['avgPace'] as String
        : _calcPaceFallback(widget.activity);

    final secs =
    (widget.activity['durationSeconds'] is int) ? widget.activity['durationSeconds'] as int : 0;
    _timeText = _formatTime(secs);

    _route = _decodeRoute(widget.activity['route']);
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return "${seconds}s";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s.toString().padLeft(2, '0')}s";
  }

  String _calcPaceFallback(Map<String, dynamic> a) {
    final dist = (a['distanceKm'] is num) ? (a['distanceKm'] as num).toDouble() : 0.0;
    final secs = (a['durationSeconds'] is int) ? a['durationSeconds'] as int : 0;
    if (dist <= 0 || secs <= 0) return "-:--";
    final minPerKm = (secs / 60.0) / dist;
    int mins = minPerKm.floor();
    int s = ((minPerKm - mins) * 60).round();
    if (s == 60) {
      mins += 1;
      s = 0;
    }
    return "$mins:${s.toString().padLeft(2, '0')}";
  }

  List<LatLng> _decodeRoute(dynamic raw) {
    final out = <LatLng>[];
    if (raw is! List) return out;
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        out.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    return out;
  }

  Future<void> _pickBackground() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Background"),
        message: Text(_isDesktop
            ? "On desktop, choose a file (camera isn't supported)."
            : "Pick an image/video background."),
        actions: [
          if (!_isDesktop)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                await _pickImageMobile(ImageSource.camera);
              },
              child: const Text("Take Photo (Camera)"),
            ),
          if (!_isDesktop)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                await _pickVideoMobile(ImageSource.camera);
              },
              child: const Text("Record Video (Camera)"),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _pickImage();
            },
            child: Text(_isDesktop ? "Choose Photo (File)" : "Choose Photo (Gallery)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _pickVideo();
            },
            child: Text(_isDesktop ? "Choose Video (File)" : "Choose Video (Gallery)"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));

      if (_isDesktop) {
        final res = await FilePicker.platform.pickFiles(type: FileType.image);
        final path = res?.files.single.path;
        if (path == null) return;
        await _setBackgroundImage(File(path));
        return;
      }

      final xf = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (xf == null) return;
      await _setBackgroundImage(File(xf.path));
    } catch (e) {
      debugPrint("pick image error: $e");
      _toast("Failed to pick image.\n$e");
    }
  }

  Future<void> _pickVideo() async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));

      if (_isDesktop) {
        final res = await FilePicker.platform.pickFiles(type: FileType.video);
        final path = res?.files.single.path;
        if (path == null) return;
        await _setBackgroundVideo(File(path));
        return;
      }

      final xf = await _picker.pickVideo(source: ImageSource.gallery);
      if (xf == null) return;
      await _setBackgroundVideo(File(xf.path));
    } catch (e) {
      debugPrint("pick video error: $e");
      _toast("Failed to pick video.\n$e");
    }
  }

  Future<void> _pickImageMobile(ImageSource src) async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final xf = await _picker.pickImage(source: src, imageQuality: 92);
      if (xf == null) return;
      await _setBackgroundImage(File(xf.path));
    } catch (e) {
      debugPrint("camera image error: $e");
      _toast("Camera failed.\n$e");
    }
  }

  Future<void> _pickVideoMobile(ImageSource src) async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final xf = await _picker.pickVideo(source: src);
      if (xf == null) return;
      await _setBackgroundVideo(File(xf.path));
    } catch (e) {
      debugPrint("camera video error: $e");
      _toast("Camera failed.\n$e");
    }
  }

  Future<void> _setBackgroundImage(File file) async {
    await _videoCtrl?.dispose();
    _videoCtrl = null;

    setState(() {
      _bgVideo = null;
      _bgImage = file;
    });
  }

  Future<void> _setBackgroundVideo(File file) async {
    await _videoCtrl?.dispose();

    final c = VideoPlayerController.file(file);
    await c.initialize();
    await c.setLooping(true);
    await c.play();

    setState(() {
      _bgImage = null;
      _bgVideo = file;
      _videoCtrl = c;
    });
  }

  Future<String> _captureKeyToPngFile(GlobalKey key, {double pixelRatio = 3.0}) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png";
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _save() async {
    // Desktop: save PNG to Downloads/Documents
    if (_isDesktop) {
      try {
        final outPng = await _captureKeyToPngFile(_fullPreviewKey);

        final downloads = await getDownloadsDirectory();
        final baseDir = downloads ?? await getApplicationDocumentsDirectory();

        final filename = "strava_share_${DateTime.now().millisecondsSinceEpoch}.png";
        final dest = File("${baseDir.path}/$filename");

        await File(outPng).copy(dest.path);
        _toast("Saved PNG:\n${dest.path}");
      } catch (e) {
        debugPrint("desktop save error: $e");
        _toast("Failed to save.\n$e");
      }
      return;
    }

    // Mobile/mac: PhotoManager
    final ps = await pm.PhotoManager.requestPermissionExtend();
    final ok = ps.isAuth || ps.hasAccess;
    if (!ok) {
      _toast("Photos permission denied.");
      return;
    }

    if (_bgVideo == null) {
      final outPng = await _captureKeyToPngFile(_fullPreviewKey);
      final saved = await pm.PhotoManager.editor.saveImageWithPath(
        outPng,
        title: "strava_share_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      _toast(saved != null ? "Saved image to Photos/Gallery." : "Failed to save image.");
      return;
    }

    // Video export (mobile/mac only) using FFmpeg + overlay
    final overlayPng = await _captureKeyToPngFile(_overlayOnlyKey);
    final inVideo = _bgVideo!.path;
    final dir = await getTemporaryDirectory();
    final outVideo = "${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.mp4";

    final cmd =
        '-y -i "$inVideo" -i "$overlayPng" '
        '-filter_complex "[1:v][0:v]scale2ref[ov][base];[base][ov]overlay=0:0:format=auto" '
        '-map 0:a? -c:a copy -c:v libx264 -preset veryfast -crf 18 "$outVideo"';

    await FFmpegKit.execute(cmd);

    final savedVideo = await pm.PhotoManager.editor.saveVideo(
      File(outVideo),
      title: "strava_share_${DateTime.now().millisecondsSinceEpoch}.mp4",
    );

    _toast(savedVideo != null ? "Saved video to Photos/Gallery." : "Failed to save video.");
  }

  void _toast(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Done"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF3F3F3);

    final overlay = _ShareOverlay(
      distanceKm: _distanceKm,
      pace: _avgPace,
      time: _timeText,
      route: _route,
    );

    return CupertinoPageScaffold(
      backgroundColor: pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Share Activity"),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            const side = 16.0;
            const topGap = 14.0;
            const btnH = 54.0;
            const bottomPad = 18.0;
            const btnRowTopPad = 8.0;

            final availableH = c.maxHeight - (topGap + btnRowTopPad + btnH + bottomPad + 10);
            final maxW = math.min(420.0, c.maxWidth - side * 2);
            final wByH = availableH * 9 / 16;

            final previewW = math.max(280.0, math.min(maxW, wByH));
            final previewH = previewW * 16 / 9;

            return Column(
              children: [
                const SizedBox(height: topGap),

                Center(
                  child: SizedBox(
                    width: previewW,
                    height: previewH,
                    child: RepaintBoundary(
                      key: _fullPreviewKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _BackgroundView(image: _bgImage, videoCtrl: _videoCtrl),
                            overlay,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Offstage(
                  offstage: true,
                  child: SizedBox(
                    width: previewW,
                    height: previewH,
                    child: RepaintBoundary(
                      key: _overlayOnlyKey,
                      child: Container(color: Colors.transparent, child: overlay),
                    ),
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(side, btnRowTopPad, side, bottomPad),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickBackground,
                          child: Container(
                            height: btnH,
                            decoration: BoxDecoration(
                              color: CupertinoColors.black,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Center(
                              child: Text(
                                "Background",
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _save,
                          child: Container(
                            height: btnH,
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeOrange,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Center(
                              child: Text(
                                "Save",
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} // ✅ IMPORTANT: closes _SharePageState

class _BackgroundView extends StatelessWidget {
  final File? image;
  final VideoPlayerController? videoCtrl;

  const _BackgroundView({required this.image, required this.videoCtrl});

  @override
  Widget build(BuildContext context) {
    if (videoCtrl != null && videoCtrl!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: videoCtrl!.value.size.width,
          height: videoCtrl!.value.size.height,
          child: VideoPlayer(videoCtrl!),
        ),
      );
    }

    if (image != null && image!.existsSync()) {
      return Image.file(image!, fit: BoxFit.cover);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF101010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _ShareOverlay extends StatelessWidget {
  final double distanceKm;
  final String pace;
  final String time;
  final List<LatLng> route;

  const _ShareOverlay({
    required this.distanceKm,
    required this.pace,
    required this.time,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 18,
          left: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
            ),
            child: const Text(
              "TRANSPARENT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Distance",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text("${distanceKm.toStringAsFixed(2)} km",
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                const SizedBox(height: 22),
                const Text("Pace",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text("$pace /km",
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                const SizedBox(height: 22),
                const Text("Time",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(time,
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                const SizedBox(height: 26),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _ShareRoutePainter(route: route),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "STRAVA",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareRoutePainter extends CustomPainter {
  final List<LatLng> route;
  _ShareRoutePainter({required this.route});

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;

    double minLat = route.first.latitude, maxLat = route.first.latitude;
    double minLng = route.first.longitude, maxLng = route.first.longitude;

    for (final p in route) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final safeLat = latSpan == 0 ? 1e-9 : latSpan;
    final safeLng = lngSpan == 0 ? 1e-9 : lngSpan;

    final pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final scale = math.min(w, h);

    Offset mapPoint(LatLng p) {
      final x = (p.longitude - minLng) / safeLng;
      final y = (maxLat - p.latitude) / safeLat; // invert
      return Offset(
        pad + x * scale + (w - scale) / 2,
        pad + y * scale + (h - scale) / 2,
      );
    }

    final path = ui.Path();
    final first = mapPoint(route.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < route.length; i++) {
      final o = mapPoint(route[i]);
      path.lineTo(o.dx, o.dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = CupertinoColors.activeOrange;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShareRoutePainter oldDelegate) => oldDelegate.route != route;
}
