/// File: target_sector_selector.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

class TargetSectorSelector extends StatelessWidget {
  final String currentTarget;
  final ValueChanged<String> onSelected;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TargetSectorSelector({
    super.key,
    required this.currentTarget,
    required this.onSelected,
  });

  static const _colorT = Color(0xFFE05252);
  static const _colorD = Color(0xFF4CAF82);
  static const _colorS = Color(0xFF5B8FE8);

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _openSelector(BuildContext context) async {

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {

        String selected = currentTarget;

        final numbers = [
          25,
          20,19,18,17,16,15,14,13,12,11,10,
          9,8,7,6,5,4,3,2,1
        ];

        /// Funzione: descrive in modo semplice questo blocco di logica.
        return StatefulBuilder(
          builder: (context, setState) {

            /// Funzione: descrive in modo semplice questo blocco di logica.
            String label(int n, String type) => "$type$n";

            /// Funzione: descrive in modo semplice questo blocco di logica.
            Widget sectorButton(
                int n,
                String type,
                String text,
                Color color,
                ) {

              final value = label(n, type);
              final active = selected == value;

              /// Funzione: descrive in modo semplice questo blocco di logica.
              return InkWell(
                onTap: () {
                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  setState(() {
                    selected = value;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: active
                        ? color.withOpacity(.15)
                        : Colors.grey.shade200,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? color : Colors.black87,
                    ),
                  ),
                ),
              );
            }

            /// Funzione: descrive in modo semplice questo blocco di logica.
            Widget card(int n) {

              final bull = n == 25;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    Center(
                      child: Text(
                        "$n",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    if (!bull)
                      sectorButton(n,"T","Triplo",_colorT),

                    if (!bull)
                      const SizedBox(height: 4),

                    sectorButton(n,"D","Doppio",_colorD),

                    const SizedBox(height: 4),

                    sectorButton(n,"S","Singolo",_colorS),

                  ],
                ),
              );
            }

            return SafeArea(
              child: Column(
                children: [

                  const SizedBox(height: 16),

                  const Text(
                    "Seleziona Target",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                      /// Funzione: descrive in modo semplice questo blocco di logica.
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: numbers.length,
                      itemBuilder: (context, i) {
                        return card(numbers[i]);
                      },
                    ),
                  ),

                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16,8,16,20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, selected);
                        },
                        child: const Text("Conferma"),
                      ),
                    ),
                  ),

                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    final color = Theme.of(context).colorScheme.primary;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.35)),
          color: color.withOpacity(.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            const Icon(Icons.gps_fixed, size: 18),

            const SizedBox(width: 6),

            Text(
              currentTarget,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(width: 4),

            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
            ),

          ],
        ),
      ),
    );
  }
}
