import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/game/presentation/pages/allenamento_screen.dart';
import '../../features/game/presentation/pages/campionati_screen.dart';
import '../../features/stats/presentation/pages/classifiche_screen.dart';
import '../../features/game/presentation/pages/gioca_screen.dart';
import '../../features/players/presentation/widgets/profile_panel.dart';
import '../../features/game/presentation/pages/tornei_screen.dart';
import '../../app/link/app_link_state.dart';
import '../../features/darts_match/presentation/lobby/pages/room_lobby_shell_page.dart';
enum AppSection {
  allenamento,
  gioca,
  campionati,
  tornei,
  classifiche,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSection = AppSection.allenamento,
  });

  final AppSection initialSection;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppSection current;

  @override
  void initState() {
    super.initState();
    current = widget.initialSection;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final container = ProviderScope.containerOf(context, listen: false);
      final linkCoordinator = container.read(appLinkCoordinatorProvider.notifier);

      final roomId = await linkCoordinator.consumeRoomId();

      if (roomId != null && roomId.isNotEmpty) {
        setState(() {
          current = AppSection.gioca;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RoomLobbyShellPage(),
          ),
        );
      }
    });
  }

  String get title {
    switch (current) {
      case AppSection.allenamento:
        return "Allenamento";
      case AppSection.gioca:
        return "Gioca";
      case AppSection.campionati:
        return "Campionati";
      case AppSection.tornei:
        return "Tornei";
      case AppSection.classifiche:
        return "Classifiche";
    }
  }

  Widget get screen {
    switch (current) {
      case AppSection.allenamento:
        return const AllenamentoScreen();
      case AppSection.gioca:
        return const GiocaScreen();
      case AppSection.campionati:
        return const CampionatiScreen();
      case AppSection.tornei:
        return const TorneiScreen();
      case AppSection.classifiche:
        return const ClassificheScreen();
    }
  }

  Widget _menuItem(
      AppSection section,
      String text,
      IconData icon,
      ) {
    final selected = current == section;

    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          current = section;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Menu",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              _menuItem(AppSection.allenamento, "Allenamento", Icons.fitness_center),
              _menuItem(AppSection.gioca, "Gioca", Icons.sports_esports),
              _menuItem(AppSection.campionati, "Campionati", Icons.emoji_events),
              _menuItem(AppSection.tornei, "Tornei", Icons.emoji_events_outlined),
              _menuItem(AppSection.classifiche, "Classifiche", Icons.leaderboard),
            ],
          ),
        ),
      ),
      endDrawer: const ProfilePanel(),
      appBar: AppBar(
        title: Text(title),
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              return Row(
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        user.email ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.account_circle),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: screen,
    );
  }
}