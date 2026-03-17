import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'activity_widgets.dart';

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

