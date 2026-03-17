import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'record_models.dart';
import 'record_summary.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();

  LatLng? _currentLocation;

  // TEMP route collected every 10s while recording
  final List<LatLng> _tempRoute = [];

  RecordMapType _mapType = RecordMapType.satellite;
  SessionState _sessionState = SessionState.setup;

  String _workoutType = "Run";
  bool _routeAdded = false;

  Duration _time = Duration.zero;
  double _distanceKm = 0.0;

  DateTime? _startedAt;

  Timer? _timer;        // 1-second stopwatch
  Timer? _sampleTimer;  // 10-second GPS sampling

  bool get _isSetup => _sessionState == SessionState.setup;
  bool get _isRunning => _sessionState == SessionState.running;
  bool get _isPaused => _sessionState == SessionState.paused;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sampleTimer?.cancel();
    super.dispose();
  }

  Future<LatLng?> _getCurrentLocationWithPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _initLocation() async {
    final loc = await _getCurrentLocationWithPermission();
    if (!mounted || loc == null) return;

    setState(() => _currentLocation = loc);
    _mapController.move(loc, 17);
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final live = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() => _currentLocation = live);

      _mapController.move(live, 17);
    } catch (e) {
      debugPrint("Failed to get current location: $e");
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == RecordMapType.satellite
          ? RecordMapType.standard
          : RecordMapType.satellite;
    });
  }

  List<Widget> _buildTileLayers() {
    if (_mapType == RecordMapType.standard) {
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

  void _startStopwatch() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _time += const Duration(seconds: 1));
    });
  }

  void _stopStopwatch() {
    _timer?.cancel();
  }

  // Capture a GPS point and append to _tempRoute
  Future<void> _capturePoint({bool force = false}) async {
    if (!force && !_isRunning) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLoc = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = newLoc;

        if (_tempRoute.isNotEmpty) {
          final meters = _distanceCalculator(_tempRoute.last, newLoc);

          // reduce jitter
          if (meters < 2 && !force) return;

          _distanceKm += meters / 1000.0;
        }

        _tempRoute.add(newLoc);
      });

      _mapController.move(newLoc, 17);
    } catch (e) {
      debugPrint("Failed to capture point: $e");
    }
  }

  void _startSamplingEvery10Seconds() {
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _capturePoint();
    });
  }

  void _stopSampling() {
    _sampleTimer?.cancel();
  }

  void _startTracking() async {
    if (_currentLocation == null) return;

    setState(() {
      _sessionState = SessionState.running;
      _startedAt = DateTime.now();
      _time = Duration.zero;
      _distanceKm = 0.0;
      _tempRoute
        ..clear()
        ..add(_currentLocation!);
    });

    await _capturePoint(force: true);

    _startStopwatch();
    _startSamplingEvery10Seconds();
  }

  void _pauseTracking() {
    _stopStopwatch();
    _stopSampling();
    setState(() => _sessionState = SessionState.paused);
  }

  void _resumeTracking() {
    setState(() => _sessionState = SessionState.running);
    _startStopwatch();
    _startSamplingEvery10Seconds();
  }

  Future<Box> _getActivitiesBox() async {
    if (Hive.isBoxOpen('activities')) return Hive.box('activities');
    return await Hive.openBox('activities');
  }

  // kept for later (Save Activity feature)
  Future<void> _saveToHive() async {
    final box = await _getActivitiesBox();

    final encodedRoute = _tempRoute
        .map((p) => [p.latitude, p.longitude])
        .toList(growable: false);

    final activity = <String, dynamic>{
      "workoutType": _workoutType,
      "startedAt": _startedAt?.toIso8601String(),
      "durationSeconds": _time.inSeconds,
      "distanceKm": double.parse(_distanceKm.toStringAsFixed(3)),
      "route": encodedRoute,
    };

    await box.add(activity);
  }

  // ✅ UPDATED: Finish -> go to SummaryScreen
  Future<void> _finishTracking() async {
    final shouldFinish = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text("Finish activity?"),
          content: const Text("This will end your current session and show the summary."),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Finish"),
            ),
          ],
        );
      },
    );

    if (shouldFinish != true) return;

    // final endpoint
    await _capturePoint(force: true);

    // stop timers
    _stopStopwatch();
    _stopSampling();

    if (!mounted) return;

    // keep it paused so "Resume" from Summary can return and resume if needed
    setState(() => _sessionState = SessionState.paused);

    final snapshotRoute = List<LatLng>.from(_tempRoute);

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SummaryScreen(
          initialWorkoutType: _workoutType,
          startedAt: _startedAt,
          duration: _time,
          distanceKm: _distanceKm,
          route: snapshotRoute,
        ),
      ),
    );
  }

  Future<void> _onWorkoutTypePressed() async {
    if (!_isSetup) return; // lock once started
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Choose workout type"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _workoutType = "Run");
              Navigator.pop(context);
            },
            child: const Text("Run"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _workoutType = "Walk");
              Navigator.pop(context);
            },
            child: const Text("Walk"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _workoutType = "Ride");
              Navigator.pop(context);
            },
            child: const Text("Ride"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  Future<void> _onAddRoutePressed() async {
    if (!_isSetup) return;
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Add Route"),
        content: const Text(
          "Route selection UI can be connected here later.\n\nFor now, this toggles whether a route is marked as added.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            onPressed: () {
              setState(() => _routeAdded = !_routeAdded);
              Navigator.pop(context);
            },
            child: Text(_routeAdded ? "Remove Route" : "Add Route"),
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  String get _avgPaceDisplay {
    if (_distanceKm <= 0 || _time.inSeconds == 0) return "-:--";
    final minutesPerKm = (_time.inSeconds / 60) / _distanceKm;
    int mins = minutesPerKm.floor();
    int secs = ((minutesPerKm - mins) * 60).round();
    if (secs == 60) {
      mins += 1;
      secs = 0;
    }
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  IconData _workoutIcon() {
    switch (_workoutType) {
      case "Walk":
        return Icons.directions_walk_rounded;
      case "Ride":
        return Icons.directions_bike_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _currentLocation == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation!,
                  initialZoom: 17,
                  minZoom: 1,
                  maxZoom: 20,
                ),
                children: [
                  ..._buildTileLayers(),
                  if (_tempRoute.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _tempRoute,
                          strokeWidth: 5,
                          color: CupertinoColors.activeOrange,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
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
            ),

            // Top-left collapse
            Positioned(
              top: 14,
              left: 14,
              child: _circleIconButton(
                icon: CupertinoIcons.chevron_down,
                onTap: () => Navigator.pop(context),
                size: 48,
              ),
            ),

            // Right-side map controls
            Positioned(
              top: 220,
              right: 14,
              child: Column(
                children: [
                  _circleIconButton(
                    icon: CupertinoIcons.layers,
                    onTap: _toggleMapType,
                    size: 52,
                  ),
                  const SizedBox(height: 12),
                  _circleIconButton(
                    icon: Icons.gps_fixed_outlined,
                    onTap: _goToCurrentLocation,
                    size: 52,
                  ),
                ],
              ),
            ),

            // Stats card
            Positioned(
              left: 20,
              right: 20,
              bottom: 205,
              child: _buildStatsCard(),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_isPaused) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                color: const Color(0xFFF2C94C),
                child: Row(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Stopped",
                          style: TextStyle(
                            color: CupertinoColors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.arrow_up_left_arrow_down_right,
                      color: CupertinoColors.black,
                      size: 18,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statBlock(value: _formatTime(_time), label: "Time", align: CrossAxisAlignment.start),
                    _statBlock(value: _avgPaceDisplay, label: "Avg. pace (/km)", align: CrossAxisAlignment.center),
                    _statBlock(value: _distanceKm.toStringAsFixed(2), label: "Distance (km)", align: CrossAxisAlignment.end),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    _workoutType,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_up_left_arrow_down_right,
                color: CupertinoColors.white,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statBlock(value: _formatTime(_time), label: "Time", align: CrossAxisAlignment.start),
              _statBlock(value: _avgPaceDisplay, label: "Avg. pace (/km)", align: CrossAxisAlignment.center),
              _statBlock(value: _distanceKm.toStringAsFixed(2), label: "Distance (km)", align: CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A).withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          if (_isSetup)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bottomAction(
                  label: _workoutType,
                  circleColor: const Color(0xFF5A3A2A),
                  icon: _workoutIcon(),
                  iconColor: CupertinoColors.activeOrange,
                  showCheck: true,
                  onTap: _onWorkoutTypePressed,
                ),
                _bottomAction(
                  label: "Start",
                  circleColor: CupertinoColors.activeOrange,
                  icon: CupertinoIcons.play_fill,
                  iconColor: CupertinoColors.white,
                  big: true,
                  onTap: _startTracking,
                ),
                _bottomAction(
                  label: _routeAdded ? "Route Added" : "Add Route",
                  circleColor: const Color(0xFF4A4A4A),
                  icon: CupertinoIcons.map,
                  iconColor: CupertinoColors.white,
                  onTap: _onAddRoutePressed,
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: _wideActionButton(
                      label: _isPaused ? "Resume" : "Pause",
                      icon: _isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                      backgroundColor: CupertinoColors.activeOrange,
                      textColor: CupertinoColors.white,
                      onTap: _isPaused ? _resumeTracking : _pauseTracking,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _wideActionButton(
                      label: "Finish",
                      icon: Icons.outlined_flag,
                      backgroundColor: CupertinoColors.white,
                      textColor: CupertinoColors.black,
                      onTap: _finishTracking,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statBlock({
    required String value,
    required String label,
    required CrossAxisAlignment align,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.systemGrey.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: CupertinoColors.white, size: 22),
      ),
    );
  }

  Widget _bottomAction({
    required String label,
    required Color circleColor,
    required IconData icon,
    required VoidCallback onTap,
    bool big = false,
    bool showCheck = false,
    Color iconColor = CupertinoColors.black,
  }) {
    final double size = big ? 84 : 64;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Transform.translate(
                    offset: big ? const Offset(2, 0) : Offset.zero,
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: big ? 34 : 28,
                    ),
                  ),
                ),
              ),
              if (showCheck)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.activeOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.check_mark,
                      color: CupertinoColors.black,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: big ? CupertinoColors.activeOrange : CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideActionButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 30),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================
   SUMMARY SCREEN (NEW)
   ========================= */
