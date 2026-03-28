import 'package:flutter/material.dart';
import '../../features/game/domain/entities/input_mode.dart';

class InputModeButton extends StatelessWidget {

  final InputMode mode;
  final ValueChanged<InputMode> onChanged;

  const InputModeButton({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {

    IconData icon;

    switch (mode) {
      case InputMode.board:
        icon = Icons.adjust;
        break;
      case InputMode.dartKeyboard:
        icon = Icons.keyboard;
        break;
      case InputMode.turnKeyboard:
        icon = Icons.dialpad;
        break;
    }

    return FloatingActionButton(
      mini: true,
      onPressed: () {

        InputMode next;

        switch (mode) {
          case InputMode.board:
            next = InputMode.dartKeyboard;
            break;
          case InputMode.dartKeyboard:
            next = InputMode.turnKeyboard;
            break;
          case InputMode.turnKeyboard:
            next = InputMode.board;
            break;
        }

        onChanged(next);
      },
      child: Icon(icon),
    );
  }
}