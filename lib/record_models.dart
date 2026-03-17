import 'package:latlong2/latlong.dart';

enum RecordMapType { standard, satellite }
enum SessionState { setup, running, paused }

class RecordState {
  final LatLng? currentLocation;
  final List<LatLng> tempRoute;
  final RecordMapType mapType;
  final SessionState sessionState;
  final String workoutType;
  final bool routeAdded;
  final Duration time;
  final double distanceKm;
  final DateTime? startedAt;

  const RecordState({
    this.currentLocation,
    this.tempRoute = const [],
    this.mapType = RecordMapType.satellite,
    this.sessionState = SessionState.setup,
    this.workoutType = 'Run',
    this.routeAdded = false,
    this.time = Duration.zero,
    this.distanceKm = 0.0,
    this.startedAt,
  });

  bool get isSetup => sessionState == SessionState.setup;
  bool get isRunning => sessionState == SessionState.running;
  bool get isPaused => sessionState == SessionState.paused;

  RecordState copyWith({
    LatLng? currentLocation,
    List<LatLng>? tempRoute,
    RecordMapType? mapType,
    SessionState? sessionState,
    String? workoutType,
    bool? routeAdded,
    Duration? time,
    double? distanceKm,
    DateTime? startedAt,
  }) {
    return RecordState(
      currentLocation: currentLocation ?? this.currentLocation,
      tempRoute: tempRoute ?? this.tempRoute,
      mapType: mapType ?? this.mapType,
      sessionState: sessionState ?? this.sessionState,
      workoutType: workoutType ?? this.workoutType,
      routeAdded: routeAdded ?? this.routeAdded,
      time: time ?? this.time,
      distanceKm: distanceKm ?? this.distanceKm,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
