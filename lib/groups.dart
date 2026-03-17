import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
