import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

/// Plays one burst of flat confetti over [child] each time [count] grows.
/// With reduced motion nothing is drawn.
class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((_) => setState(() {}));
  var _seed = 0;

  @override
  void didUpdateWidget(Celebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count &&
        !MediaQuery.disableAnimationsOf(context)) {
      _seed = widget.count;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: CelebrationPainter(
                    progress: _controller,
                    seed: _seed,
                    colors: [
                      tokens.primary,
                      tokens.operation,
                      tokens.correct,
                      tokens.streak,
                      tokens.xp,
                      tokens.combo,
                      tokens.sprint,
                      tokens.wrong,
                    ],
                    outline: tokens.outline,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Outlined circles and squares thrown up from both side edges, falling
/// back under gravity and shrinking away by the end. They stay in the outer
/// thirds, clear of the question in the middle.
class CelebrationPainter extends CustomPainter {
  CelebrationPainter({
    required this.progress,
    required this.seed,
    required this.colors,
    required this.outline,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final int seed;
  final List<Color> colors;
  final Color outline;

  static const _count = 36;

  /// In area heights per unit of time squared: what is thrown up at the
  /// fastest speed lands back at its starting height at the end.
  static const _gravity = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final random = Random(seed);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppTokens.outlineWidth
      ..color = outline;
    for (var i = 0; i < _count; i++) {
      final left = i < _count / 2;
      final across = size.width * (.05 + .3 * random.nextDouble());
      final up = size.height * (.45 + .45 * random.nextDouble());
      final side = 9 + 9 * random.nextDouble();
      final spin = (random.nextDouble() - .5) * 4 * pi;
      final position = Offset(
        left ? across * t : size.width - across * t,
        size.height * (.55 + _gravity / 2 * t * t) - up * t,
      );
      final shrink = t < .7 ? 1.0 : (1 - t) / .3;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: side * shrink,
        height: side * shrink,
      );
      final fill = Paint()..color = colors[i % colors.length];
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(spin * t);
      if (i.isEven) {
        canvas
          ..drawOval(rect, fill)
          ..drawOval(rect, edge);
      } else {
        final square = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas
          ..drawRRect(square, fill)
          ..drawRRect(square, edge);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.colors != colors ||
      oldDelegate.outline != outline;
}
