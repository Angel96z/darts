import 'package:flutter/material.dart';
import 'allenamento_screen.dart';
import 'campionati_screen.dart';
import 'classifiche_screen.dart';
import 'gioca_screen.dart';
import 'profile_panel.dart';
import 'tornei_screen.dart';

enum AppSection {
  allenamento,
  gioca,
  campionati,
  tornei,
  classifiche,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSection current = AppSection.allenamento;

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
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          )
        ],
      ),
      body: screen,
    );
  }
}