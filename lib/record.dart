import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

enum RecordMapType { standard, satellite }
enum SessionState { setup, running, paused }

class _RecordPageState extends State<RecordPage> {
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

enum SummaryMapType { standard, satellite }

class SummaryScreen extends StatefulWidget {
  final String initialWorkoutType;
  final DateTime? startedAt;
  final Duration duration;
  final double distanceKm;
  final List<LatLng> route;

  const SummaryScreen({
    super.key,
    required this.initialWorkoutType,
    required this.startedAt,
    required this.duration,
    required this.distanceKm,
    required this.route,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController =
  TextEditingController(text: "Night Run");
  final TextEditingController _captionController = TextEditingController();

  SummaryMapType _mapType = SummaryMapType.satellite;
  late String _workoutType;

  // Draft folder id (so you can discard and delete files cleanly)
  late final String _draftId;

  // Media list (images + videos)
  final List<_MediaItem> _media = [];

  @override
  void initState() {
    super.initState();
    _workoutType = widget.initialWorkoutType;
    _draftId = "draft_${DateTime.now().millisecondsSinceEpoch}";

    // Fit route to map after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitRouteToMap();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _fitRouteToMap() {
    final route = widget.route;
    if (route.length < 2) return;

    final bounds = LatLngBounds.fromPoints(route);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(28),
      ),
    );
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == SummaryMapType.satellite
          ? SummaryMapType.standard
          : SummaryMapType.satellite;
    });
  }

  List<Widget> _buildTileLayers() {
    if (_mapType == SummaryMapType.standard) {
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

  Future<void> _pickWorkoutType() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Activity Type"),
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

  // ---------- MEDIA (Camera/Gallery) ----------

  Future<String> _persistToDraft(XFile xf, _MediaType type) async {
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory("${docs.path}/activity_drafts/$_draftId");
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final ext = () {
      final p = xf.path;
      final dot = p.lastIndexOf('.');
      if (dot == -1) return (type == _MediaType.video) ? "mp4" : "jpg";
      return p.substring(dot + 1);
    }();

    final filename = "${DateTime.now().microsecondsSinceEpoch}.$ext";
    final newPath = "${folder.path}/$filename";

    await File(xf.path).copy(newPath);
    return newPath;
  }

  Future<void> _addMediaActionSheet() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Add Photos/Video"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final xf = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
              if (xf == null) return;
              final saved = await _persistToDraft(xf, _MediaType.image);
              if (!mounted) return;
              setState(() => _media.add(_MediaItem(type: _MediaType.image, path: saved)));
            },
            child: const Text("Take Photo (Camera)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final xf = await _picker.pickVideo(source: ImageSource.camera);
              if (xf == null) return;
              final saved = await _persistToDraft(xf, _MediaType.video);
              if (!mounted) return;
              setState(() => _media.add(_MediaItem(type: _MediaType.video, path: saved)));
            },
            child: const Text("Record Video (Camera)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final list = await _picker.pickMultiImage(imageQuality: 90);
              if (list.isEmpty) return;

              final savedPaths = <String>[];
              for (final xf in list) {
                savedPaths.add(await _persistToDraft(xf, _MediaType.image));
              }

              if (!mounted) return;
              setState(() {
                for (final p in savedPaths) {
                  _media.add(_MediaItem(type: _MediaType.image, path: p));
                }
              });
            },
            child: const Text("Choose Photos (Gallery)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final xf = await _picker.pickVideo(source: ImageSource.gallery);
              if (xf == null) return;
              final saved = await _persistToDraft(xf, _MediaType.video);
              if (!mounted) return;
              setState(() => _media.add(_MediaItem(type: _MediaType.video, path: saved)));
            },
            child: const Text("Choose Video (Gallery)"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  // ---------- SAVE / DISCARD (Hive per activity) ----------

  double _avgPaceMinPerKm() {
    if (widget.distanceKm <= 0 || widget.duration.inSeconds <= 0) return 0;
    return (widget.duration.inSeconds / 60.0) / widget.distanceKm;
  }

  String _avgPaceDisplay() {
    final pace = _avgPaceMinPerKm();
    if (pace <= 0) return "-:--";
    int mins = pace.floor();
    int secs = ((pace - mins) * 60).round();
    if (secs == 60) {
      mins += 1;
      secs = 0;
    }
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  Future<void> _saveActivity() async {
    // Create an activity id
    final activityId = (widget.startedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch)
        .toString();

    final activityBoxName = "activity_$activityId";

    // Move draft media into final activity folder
    final docs = await getApplicationDocumentsDirectory();
    final finalFolder = Directory("${docs.path}/activities/$activityId/media");
    await finalFolder.create(recursive: true);

    final finalMedia = <Map<String, dynamic>>[];
    for (final item in _media) {
      final src = File(item.path);
      if (!await src.exists()) continue;

      final ext = () {
        final p = src.path;
        final dot = p.lastIndexOf('.');
        if (dot == -1) return (item.type == _MediaType.video) ? "mp4" : "jpg";
        return p.substring(dot + 1);
      }();

      final newPath =
          "${finalFolder.path}/${DateTime.now().microsecondsSinceEpoch}.$ext";
      await src.copy(newPath);

      finalMedia.add({
        "type": item.type == _MediaType.image ? "image" : "video",
        "path": newPath,
      });
    }

    // Encode route
    final encodedRoute = widget.route
        .map((p) => [p.latitude, p.longitude])
        .toList(growable: false);

    final activityData = <String, dynamic>{
      "id": activityId,
      "title": _titleController.text.trim(),
      "caption": _captionController.text.trim(),
      "workoutType": _workoutType,
      "startedAt": widget.startedAt?.toIso8601String(),
      "durationSeconds": widget.duration.inSeconds,
      "distanceKm": double.parse(widget.distanceKm.toStringAsFixed(3)),
      "avgPace": _avgPaceDisplay(),
      "route": encodedRoute,
      "media": finalMedia, // list of {type, path}
    };

    // Each activity gets its own box (as you requested)
    final activityBox = await Hive.openBox(activityBoxName);
    await activityBox.put("data", activityData);

    // Also store an index record so you can list activities later
    final indexBox = await Hive.openBox("activities_index");
    await indexBox.add({
      "id": activityId,
      "box": activityBoxName,
      "title": activityData["title"],
      "workoutType": activityData["workoutType"],
      "startedAt": activityData["startedAt"],
      "distanceKm": activityData["distanceKm"],
      "durationSeconds": activityData["durationSeconds"],
      "previewMediaPath": finalMedia.isNotEmpty ? finalMedia.first["path"] : null,
      "previewMediaType": finalMedia.isNotEmpty ? finalMedia.first["type"] : null,
    });

    if (!mounted) return;

    // Return to main
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _discardActivity() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Discard Activity?"),
        content: const Text("This will delete any selected media and return to the main screen."),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Discard"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Delete draft media folder
    try {
      final docs = await getApplicationDocumentsDirectory();
      final draftFolder = Directory("${docs.path}/activity_drafts/$_draftId");
      if (await draftFolder.exists()) {
        await draftFolder.delete(recursive: true);
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B0B0B);
    final card = const Color(0xFF121214);

    final route = widget.route;
    final hasRoute = route.length > 1;
    final center = route.isNotEmpty ? route.first : const LatLng(0, 0);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF111111),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Resume",
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        middle: const Text(
          "Save Activity",
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 140), // extra space for bottom button
              children: [
                // Title field
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                  ),
                  child: CupertinoTextField(
                    controller: _titleController,
                    placeholder: "Night Run",
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 18),
                    placeholderStyle: TextStyle(
                      color: CupertinoColors.systemGrey.withOpacity(0.8),
                      fontSize: 18,
                    ),
                    decoration: const BoxDecoration(color: Colors.transparent),
                  ),
                ),
                const SizedBox(height: 14),

                // Caption field
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                  ),
                  child: CupertinoTextField(
                    controller: _captionController,
                    placeholder:
                    "How'd it go? Share more about your\nactivity and use @ to tag someone.",
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    maxLines: 4,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 18),
                    placeholderStyle: TextStyle(
                      color: CupertinoColors.systemGrey.withOpacity(0.65),
                      fontSize: 18,
                    ),
                    decoration: const BoxDecoration(color: Colors.transparent),
                  ),
                ),
                const SizedBox(height: 14),

                // Workout type selector
                GestureDetector(
                  onTap: _pickWorkoutType,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.sportscourt,
                            color: CupertinoColors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          _workoutType,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(CupertinoIcons.chevron_down,
                            color: CupertinoColors.white, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Map + Add Photo row
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 120,
                          color: card,
                          child: hasRoute
                              ? FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: 13,
                              interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none),
                            ),
                            children: [
                              ..._buildTileLayers(),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: route,
                                    strokeWidth: 4,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: route.first,
                                    width: 18,
                                    height: 18,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.activeGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: CupertinoColors.white,
                                            width: 3),
                                      ),
                                    ),
                                  ),
                                  Marker(
                                    point: route.last,
                                    width: 18,
                                    height: 18,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemRed,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: CupertinoColors.white,
                                            width: 3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                              : const Center(
                            child: Text(
                              "No route captured",
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 120,
                        child: GestureDetector(
                          onTap: _addMediaActionSheet,
                          child: DashedBorder(
                            radius: 14,
                            dash: 7,
                            gap: 5,
                            color: CupertinoColors.activeOrange.withOpacity(0.9),
                            child: _media.isEmpty
                                ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(CupertinoIcons.photo_on_rectangle,
                                      color: CupertinoColors.activeOrange,
                                      size: 26),
                                  SizedBox(height: 10),
                                  Text(
                                    "Add Photos/Video",
                                    style: TextStyle(
                                      color: CupertinoColors.activeOrange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  _mediaThumb(_media[0]),
                                  const SizedBox(width: 8),
                                  if (_media.length > 1) _mediaThumb(_media[1]),
                                  const Spacer(),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        CupertinoIcons.plus_circle_fill,
                                        color: CupertinoColors.activeOrange,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "${_media.length} added",
                                        style: const TextStyle(
                                          color: CupertinoColors.activeOrange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Change map type button
                GestureDetector(
                  onTap: () {
                    _toggleMapType();
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _fitRouteToMap());
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      border:
                      Border.all(color: CupertinoColors.activeOrange, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        "Change Map Type",
                        style: TextStyle(
                          color: CupertinoColors.activeOrange,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // Discard Activity (kept)
                Center(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: _discardActivity,
                    child: const Text(
                      "Discard Activity",
                      style: TextStyle(
                        color: CupertinoColors.activeOrange,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ✅ Bottom Save Button (fixed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                decoration: BoxDecoration(
                  color: bg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: _saveActivity,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeOrange,
                      borderRadius: BorderRadius.circular(38),
                    ),
                    child: const Center(
                      child: Text(
                        "Save Activity",
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaThumb(_MediaItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFF1A1A1C),
        child: item.type == _MediaType.image
            ? Image.file(File(item.path), fit: BoxFit.cover)
            : const Center(
          child: Icon(CupertinoIcons.play_fill,
              color: CupertinoColors.white, size: 22),
        ),
      ),
    );
  }
}

enum _MediaType { image, video }

class _MediaItem {
  final _MediaType type;
  final String path;
  const _MediaItem({required this.type, required this.path});
}

/* =========================
   DASHED BORDER (NO PACKAGE)
   ========================= */

class DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final double dash;
  final double gap;
  final Color color;

  const DashedBorder({
    super.key,
    required this.child,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        radius: radius,
        dash: dash,
        gap: gap,
        color: color,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          color: const Color(0xFF121214),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final double radius;
  final double dash;
  final double gap;
  final Color color;

  _DashedRRectPainter({
    required this.radius,
    required this.dash,
    required this.gap,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // We'll draw dashed lines around the bounding rect (simple + clean).
    // (It visually matches Strava enough without heavy path-metrics.)
    _dashedLine(canvas, paint, Offset(radius, 0), Offset(size.width - radius, 0)); // top
    _dashedLine(canvas, paint, Offset(radius, size.height), Offset(size.width - radius, size.height)); // bottom
    _dashedLine(canvas, paint, Offset(0, radius), Offset(0, size.height - radius)); // left
    _dashedLine(canvas, paint, Offset(size.width, radius), Offset(size.width, size.height - radius)); // right

    // corners (small arcs)
    canvas.drawArc(Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        math.pi, math.pi / 2, false, paint);
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width - radius, radius), radius: radius),
        -math.pi / 2, math.pi / 2, false, paint);
    canvas.drawArc(Rect.fromCircle(center: Offset(radius, size.height - radius), radius: radius),
        math.pi / 2, math.pi / 2, false, paint);
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width - radius, size.height - radius), radius: radius),
        0, math.pi / 2, false, paint);

    // optional: keep the clip consistent
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.restore();
  }

  void _dashedLine(Canvas canvas, Paint paint, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final dir = Offset(dx / length, dy / length);

    double drawn = 0;
    while (drawn < length) {
      final start = a + dir * drawn;
      final end = a + dir * math.min(drawn + dash, length);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color;
  }
}