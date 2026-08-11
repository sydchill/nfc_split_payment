import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Patela mark — a geometric "P" whose bowl is drawn as contactless payment
/// waves, so the monogram doubles as a tap-to-pay motif.
///
/// Built from paths (no assets) so it stays crisp at any size and can be
/// recoloured for light/dark surfaces.
class PatelaMark extends StatelessWidget {
  const PatelaMark({
    super.key,
    this.size = 52,
    this.color = T.indigo,
    this.waveColor,
  });

  final double size;

  /// Colour of the stem and (by default) the waves.
  final Color color;

  /// Optional distinct colour for the waves — defaults to [color].
  final Color? waveColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PatelaMarkPainter(color, waveColor ?? color),
    );
  }
}

class _PatelaMarkPainter extends CustomPainter {
  const _PatelaMarkPainter(this.color, this.waveColor);

  final Color color;
  final Color waveColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Design on a 48x48 grid, then scale.
    final s = size.width / 48;
    canvas.scale(s, s);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Vertical stem of the P. Sits left of centre so the waves have room.
    stroke
      ..color = color
      ..strokeWidth = 6;
    canvas.drawLine(const Offset(12, 7), const Offset(12, 41), stroke);

    // Bowl of the P rendered as three concentric contactless arcs, radiating
    // from the upper stem — the "tap" gesture.
    const center = Offset(12, 18);
    // Arc sweep: from roughly -70° to +70° around the stem (opening right).
    double rad(double deg) => deg * math.pi / 180;

    final arcs = <List<double>>[
      // radius, strokeWidth
      [8, 5.5],
      [15, 4.5],
      [22, 3.5],
    ];
    for (var i = 0; i < arcs.length; i++) {
      stroke.strokeWidth = arcs[i][1];
      // Outer arcs fade slightly, giving the radiating feel.
      stroke.color = waveColor.withValues(alpha: i == 0 ? 1 : (i == 1 ? .7 : .4));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcs[i][0]),
        rad(-72),
        rad(144),
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PatelaMarkPainter old) =>
      old.color != color || old.waveColor != waveColor;
}

/// The mark inside a rounded "app icon" tile — used on the welcome screen.
class PatelaLogoTile extends StatelessWidget {
  const PatelaLogoTile({
    super.key,
    this.size = 72,
    this.background = Colors.white,
    this.markColor = T.indigo,
  });

  final double size;
  final Color background;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .4),
            blurRadius: size * .42,
            offset: Offset(0, size * .17),
            spreadRadius: -size * .11,
          ),
        ],
      ),
      child: Center(child: PatelaMark(size: size * .62, color: markColor)),
    );
  }
}

/// Wordmark: the mark beside "Patela", for headers and light surfaces.
class PatelaWordmark extends StatelessWidget {
  const PatelaWordmark({
    super.key,
    this.fontSize = 26,
    this.color = T.ink,
    this.markColor = T.indigo,
  });

  final double fontSize;
  final Color color;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PatelaMark(size: fontSize * 1.15, color: markColor),
        SizedBox(width: fontSize * .34),
        Text(
          'Patela',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -fontSize * .028,
          ),
        ),
      ],
    );
  }
}
