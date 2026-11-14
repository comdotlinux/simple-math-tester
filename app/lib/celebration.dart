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

/// Outlined circles and squares burst from eight points (three up each side
/// edge, one at the top middle, one at the bottom middle), falling under
/// gravity and shrinking away by the end. The burst is over in about a
/// second and lets pointers through, so crossing the question is fine.
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

  /// Five times the first burst of 36: the owner found 36 too thin to pop.
  static const _count = 180;

  /// In area heights per unit of time squared.
  static const _gravity = 1.8;

  /// Where the bursts start, as fractions of the area's width and height.
  static const origins = [
    Offset(0, .25),
    Offset(0, .5),
    Offset(0, .75),
    Offset(1, .25),
    Offset(1, .5),
    Offset(1, .75),
    Offset(.5, 0),
    Offset(.5, 1),
  ];

  /// Where each piece is at time [t] (0 to 1); piece i starts at
  /// `origins[i % origins.length]`. Side pieces fly inwards and up, top
  /// pieces fan out downwards, bottom pieces are thrown up and fall back.
  static List<Offset> positions(Size size, double t, int seed) {
    final random = Random(seed);
    return [
      for (var i = 0; i < _count; i++)
        () {
          final origin = origins[i % origins.length];
          final a = random.nextDouble(), b = random.nextDouble();
          final velocity = switch (origin.dx) {
            0 => Offset(.15 + .3 * a, -(.3 + .5 * b)),
            1 => Offset(-(.15 + .3 * a), -(.3 + .5 * b)),
            _ when origin.dy == 0 => Offset((a - .5) * .8, .1 + .3 * b),
            _ => Offset((a - .5) * .8, -(.9 + .5 * b)),
          };
          return Offset(
            size.width * (origin.dx + velocity.dx * t),
            size.height * (origin.dy + velocity.dy * t + _gravity / 2 * t * t),
          );
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final random = Random(seed + 1);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppTokens.outlineWidth
      ..color = outline;
    final all = positions(size, t, seed);
    for (var i = 0; i < _count; i++) {
      final side = 9 + 9 * random.nextDouble();
      final spin = (random.nextDouble() - .5) * 4 * pi;
      // Random, not i.isEven: that would make each burst point one shape.
      final round = random.nextBool();
      final position = all[i];
      final shrink = t < .7 ? 1.0 : (1 - t) / .3;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: side * shrink,
        height: side * shrink,
      );
      // Each burst point cycles through every colour in turn (i % length
      // would give each of the eight points a single colour).
      final fill = Paint()
        ..color = colors[(i ~/ origins.length) % colors.length];
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(spin * t);
      if (round) {
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
