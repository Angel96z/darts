/// File: target_sector_selector.dart

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';

class TargetSectorSelector extends StatelessWidget {
  final String currentTarget;
  final ValueChanged<String> onSelected;
  final bool enabled;

  const TargetSectorSelector({
    super.key,
    required this.currentTarget,
    required this.onSelected,
    this.enabled = true,
  });

  static const List<int> _numbers = [
    25, 20, 19, 18, 17, 16, 15, 14, 13, 12,
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
  ];

  Future<void> _openSelector(BuildContext context) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi',
      barrierColor: Colors.black.withOpacity(0.58),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(c),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => _SectorOverlay(
        currentTarget: currentTarget,
        numbers: _numbers,
      ),
    );

    if (result != null && result != currentTarget) {
      onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final parsed = _TargetParts.from(currentTarget);

    if (!enabled) {
      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Target bloccato: salva o annulla tutti i tiri per cambiarlo.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(parsed.type, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: t.accent, height: 1)),
              Text('${parsed.number}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: t.textPrimary, height: 1)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.accent.withOpacity(0.35)),
          color: t.accent.withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TARGET',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: t.accent,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              parsed.type,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: t.accent,
              ),
            ),
            Text(
              '${parsed.number}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TargetParts {
  final String type;
  final int number;

  const _TargetParts({
    required this.type,
    required this.number,
  });

  factory _TargetParts.from(String value) {
    if (value.startsWith('S')) {
      return _TargetParts(type: 'S', number: int.tryParse(value.substring(1)) ?? 25);
    }
    if (value.startsWith('D')) {
      return _TargetParts(type: 'D', number: int.tryParse(value.substring(1)) ?? 25);
    }
    if (value.startsWith('T')) {
      return _TargetParts(type: 'T', number: int.tryParse(value.substring(1)) ?? 20);
    }
    return _TargetParts(type: 'S', number: int.tryParse(value) ?? 25);
  }

  String get label => '$type$number';
}

class _SectorOverlay extends StatefulWidget {
  final String currentTarget;
  final List<int> numbers;

  const _SectorOverlay({
    required this.currentTarget,
    required this.numbers,
  });

  @override
  State<_SectorOverlay> createState() => _SectorOverlayState();
}

class _SectorOverlayState extends State<_SectorOverlay> {
  late String _selectedType;
  late int _selectedNumber;
  late FixedExtentScrollController _numberController;

  int get _selectedIndex {
    final index = widget.numbers.indexOf(_selectedNumber);
    return index < 0 ? 0 : index;
  }

  String get _selectedLabel => '$_selectedType$_selectedNumber';

  @override
  void initState() {
    super.initState();

    final parsed = _TargetParts.from(widget.currentTarget);
    _selectedType = parsed.type;
    _selectedNumber = widget.numbers.contains(parsed.number) ? parsed.number : widget.numbers.first;

    if (_selectedNumber == 25 && _selectedType == 'T') {
      _selectedType = 'D';
    }

    _numberController = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _setType(String type) {
    if (_selectedNumber == 25 && type == 'T') return;
    setState(() => _selectedType = type);
  }

  void _setNumberByIndex(int index) {
    final n = widget.numbers[index];

    setState(() {
      _selectedNumber = n;
      if (_selectedNumber == 25 && _selectedType == 'T') {
        _selectedType = 'D';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final mq = MediaQuery.of(context);
    final maxWidth = mq.size.width >= 600 ? 430.0 : mq.size.width * 0.92;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mq.size.width * 0.04,
          vertical: mq.size.height * 0.08,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: maxWidth,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border.withOpacity(0.75)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seleziona target',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: t.border),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: t.divider),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 74,
                        child: Column(
                          children: [
                            _MultiplierButton(
                              label: 'S',
                              selected: _selectedType == 'S',
                              enabled: true,
                              t: t,
                              onTap: () => _setType('S'),
                            ),
                            const SizedBox(height: 10),
                            _MultiplierButton(
                              label: 'D',
                              selected: _selectedType == 'D',
                              enabled: true,
                              t: t,
                              onTap: () => _setType('D'),
                            ),
                            const SizedBox(height: 10),
                            _MultiplierButton(
                              label: 'T',
                              selected: _selectedType == 'T',
                              enabled: _selectedNumber != 25,
                              t: t,
                              onTap: () => _setType('T'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 18),

                      Expanded(
                        child: Container(
                          height: 246,
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: t.border),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 74,
                                margin: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: t.accent.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: t.accent.withOpacity(0.38),
                                    width: 1.3,
                                  ),
                                ),
                              ),
                              ListWheelScrollView.useDelegate(
                                controller: _numberController,
                                itemExtent: 74,
                                diameterRatio: 1.45,
                                perspective: 0.004,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: _setNumberByIndex,
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: widget.numbers.length,
                                  builder: (context, index) {
                                    final n = widget.numbers[index];
                                    final selected = n == _selectedNumber;

                                    return Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 130),
                                        style: TextStyle(
                                          fontSize: selected ? 54 : 34,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                          color: selected ? t.accent : t.textMuted,
                                          letterSpacing: -1,
                                        ),
                                        child: Text('$n'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: t.divider),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _selectedLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: t.accent,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, _selectedLabel),
                          style: FilledButton.styleFrom(
                            backgroundColor: t.accent,
                            foregroundColor: t.accentFg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Conferma',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiplierButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final dynamic t;
  final VoidCallback onTap;

  const _MultiplierButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surfaceHigh,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: t.accent.withOpacity(0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
              color: selected ? t.accentFg : t.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}