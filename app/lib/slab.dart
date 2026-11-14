import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

/// Puts the hard shadow under [child]: a solid slab, no blur, that the child
/// sinks onto while a pointer presses it ([pressable]) or while [down].
class Slab extends StatefulWidget {
  const Slab({
    super.key,
    required this.child,
    this.radius = AppTokens.radiusCard,
    this.pressable = false,
    this.down = false,
  });

  final Widget child;
  final double radius;
  final bool pressable;
  final bool down;

  @override
  State<Slab> createState() => _SlabState();
}

class _SlabState extends State<Slab> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (widget.pressable && pressed != _pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final down = widget.down || _pressed;
    final depth = down ? AppTokens.pressedDepth : AppTokens.depth;
    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 70),
        // Sinking by what the slab loses keeps its bottom edge still.
        transform: Matrix4.translationValues(0, AppTokens.depth - depth, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(color: context.tokens.shadow, offset: Offset(0, depth)),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
