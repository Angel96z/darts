import 'package:flutter/material.dart';

enum OverlayState { loading, success, error }

class BlockingOverlay extends StatelessWidget {
  final OverlayState state;
  final String? message;
  final VoidCallback? onClose;

  const BlockingOverlay({
    super.key,
    required this.state,
    this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (state) {
      case OverlayState.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case OverlayState.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.white;
    }

    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Card(
          color: const Color(0xFF1E1E1E),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state == OverlayState.loading)
                  const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(),
                  )
                else
                  Icon(icon, color: color, size: 60),

                const SizedBox(height: 20),

                Text(
                  message ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (state == OverlayState.error) ...[
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}