import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:video_player/video_player.dart';
import 'share_page.dart';
import 'app_utils.dart';

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
      return deepMap(raw);
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
      out.add(_LegacyItem(atIndex: i, data: deepMap(raw)));
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
  void deactivate() {
    _controller?.pause();
    super.deactivate();
  }

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
      await _controller!.setVolume(0);
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
