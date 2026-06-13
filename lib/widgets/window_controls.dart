import 'package:flutter/material.dart';
import '../services/window.dart';

class WindowControls extends StatefulWidget {
  final Color dateTextColor;
  const WindowControls({super.key, required this.dateTextColor});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _groupHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _groupHovered = true),
      onExit: (_) => setState(() => _groupHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            color: const Color(0xFFFFBD2E), // yellow
            icon: Icons.remove,
            onPressed: () => WindowService.minimize(),
            tooltip: "Minimize",
          ),
          const SizedBox(width: 8),
          _buildButton(
            color: const Color(0xFF27C93F), // green
            icon: Icons.crop_square,
            onPressed: () => WindowService.maximize(),
            tooltip: "Maximize",
          ),
          const SizedBox(width: 8),
          _buildButton(
            color: const Color(0xFFFF5F56), // red
            icon: Icons.close,
            onPressed: () => WindowService.close(),
            tooltip: "Close",
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _groupHovered ? color : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _groupHovered ? 1.0 : 0.0,
                child: Icon(
                  icon,
                  size: 11,
                  color: color == const Color(0xFFFFBD2E) ? Colors.black87 : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
