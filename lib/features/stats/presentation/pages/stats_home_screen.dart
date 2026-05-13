/// stats_home_screen.dart - Home con selettore Bull/X01/Cricket

import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../game/domain/entities/training_mode.dart';
import '../widgets/stats_mode_selector.dart';
import 'training_stats_screen.dart';
import 'x01_stats_screen.dart';
import 'cricket_stats_screen.dart';

class StatsHomeScreen extends StatefulWidget {
  const StatsHomeScreen({super.key});

  @override
  State<StatsHomeScreen> createState() => _StatsHomeScreenState();
}

class _StatsHomeScreenState extends State<StatsHomeScreen> {
  StatsGameMode _selectedMode = StatsGameMode.bull;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onModeChanged(StatsGameMode mode) {
    setState(() => _selectedMode = mode);
    _pageController.animateToPage(
      mode.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistiche'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatsModeSelector(
              selectedMode: _selectedMode,
              onModeChanged: _onModeChanged,
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: t.bg,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),  // ← DISABILITA SCROLL ORIZZONTALE
        onPageChanged: (index) {
          setState(() => _selectedMode = StatsGameMode.values[index]);
        },
        children: [
          const TrainingStatsScreen(
            title: 'Bullseye',
            mode: TrainingMode.bull,
            showAppBar: false,
          ),
          X01StatsWidget(
            title: 'X01',
            showAppBar: false,
          ),
          const CricketStatsScreen(showAppBar: false),
        ],
      ),
    );
  }
}