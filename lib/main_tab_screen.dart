import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import 'groups.dart';
import 'home.dart';
import 'map_screen.dart';
import 'record.dart';
import 'you.dart';

class MainTabScreen extends ConsumerWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const RecordPage(),
              ),
            );
          } else {
            ref.read(currentTabIndexProvider.notifier).state = index;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.map), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.circle), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: 'You'),
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
            return const Home();
        }
      },
    );
  }
}
