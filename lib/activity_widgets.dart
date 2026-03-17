import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

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
