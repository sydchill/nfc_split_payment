import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Buttons & chrome
// ---------------------------------------------------------------------------

class TButton extends StatelessWidget {
  const TButton({
    super.key,
    required this.onTap,
    this.label,
    this.child,
    this.bg = T.indigo,
    this.fg = Colors.white,
    this.height = 56,
    this.radius = 16,
    this.fontSize = 17,
    this.border,
  });

  final VoidCallback? onTap;
  final String? label;
  final Widget? child;
  final Color bg;
  final Color fg;
  final double height;
  final double radius;
  final double fontSize;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          child: Center(
            child: child ??
                Text(
                  label!,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg),
                ),
          ),
        ),
      ),
    );
  }
}

class BackChevronRow extends StatelessWidget {
  const BackChevronRow({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Text('‹', style: TextStyle(fontSize: 22, color: T.muted, height: 1)),
          ),
        ),
        Text(title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: T.ink)),
      ],
    );
  }
}

class BackTextButton extends StatelessWidget {
  const BackTextButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('‹ Back',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.muted)),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.bg, required this.fg, this.dot});

  final String text;
  final Color bg;
  final Color fg;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
                width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 44,
    this.fontSize = 15,
    this.radius,
  });

  final String initials;
  final Color color;
  final double size;
  final double fontSize;

  /// Null renders a circle; a value renders a rounded square.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.ink)),
        const SizedBox(height: 7),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            autocorrect: !obscure,
            enableSuggestions: !obscure,
            style: const TextStyle(fontSize: 15, color: T.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: T.faint, fontSize: 15),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: T.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: T.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: T.indigo, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ColoredBox(color: T.border, child: SizedBox(height: 1))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: TextStyle(fontSize: 12, color: T.faint, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: ColoredBox(color: T.border, child: SizedBox(height: 1))),
      ],
    );
  }
}

class FooterLink extends StatelessWidget {
  const FooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
    this.light = false,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: '$prompt ',
          style: TextStyle(
              fontSize: 13, color: light ? Colors.white.withValues(alpha: .6) : T.muted),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  action,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: light ? Colors.white : T.indigo),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in an Activity / Recent list, backed by a [Txn].
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, this.onTap});

  final Txn txn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget leading = txn.isSale
        ? Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: T.peachSoft, borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: StrokeIcon(AppIcons.card, size: 18, color: T.indigo, strokeWidth: 2.2)),
          )
        : Avatar(initials: txn.initials, color: txn.color, radius: 12);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.divider))),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: T.ink)),
                  if (txn.subtitle != null)
                    Text(txn.subtitle!,
                        style: const TextStyle(fontSize: 13, color: T.muted)),
                ],
              ),
            ),
            Text(txn.amountStr,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: txn.positive ? T.indigo : T.ink)),
          ],
        ),
      ),
    );
  }
}

/// Centered friendly empty-state for lists with no data yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: 40),
  });

  final PathBuilder icon;
  final String title;
  final String subtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: T.indigoSoft, shape: BoxShape.circle),
            child: Center(child: StrokeIcon(icon, size: 26, color: T.indigo)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.45, color: T.muted)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stroke icons (paths lifted from the design's inline SVGs, 24x24 space)
// ---------------------------------------------------------------------------

typedef PathBuilder = void Function(Path p);

class StrokeIcon extends StatelessWidget {
  const StrokeIcon(
    this.builder, {
    super.key,
    this.size = 24,
    this.color = T.ink,
    this.strokeWidth = 2,
  });

  final PathBuilder builder;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StrokePainter(builder, color, strokeWidth),
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.builder, this.color, this.strokeWidth);

  final PathBuilder builder;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path();
    builder(p);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.builder != builder || old.color != color || old.strokeWidth != strokeWidth;
}

abstract final class AppIcons {
  /// Contactless "waves" mark used on tap-to-pay surfaces.
  static void waves(Path p) {
    p
      ..moveTo(6, 8)
      ..arcToPoint(const Offset(6, 16), radius: const Radius.circular(8), clockwise: false)
      ..moveTo(9.5, 5.5)
      ..arcToPoint(const Offset(9.5, 18.5), radius: const Radius.circular(12), clockwise: false)
      ..moveTo(13, 3)
      ..arcToPoint(const Offset(13, 21), radius: const Radius.circular(16), clockwise: false);
  }

  /// Four-arc variant shown on the business "tap to pay" screen.
  static void wavesWide(Path p) {
    waves(p);
    p
      ..moveTo(16.5, 5.5)
      ..arcToPoint(const Offset(16.5, 18.5), radius: const Radius.circular(12), clockwise: true);
  }

  /// Diagonal split arrows on the "Split a bill" hero.
  static void split(Path p) {
    p
      ..moveTo(16, 3)
      ..lineTo(21, 3)
      ..lineTo(21, 8)
      ..moveTo(8, 21)
      ..lineTo(3, 21)
      ..lineTo(3, 16)
      ..moveTo(21, 3)
      ..lineTo(14, 10)
      ..moveTo(3, 21)
      ..lineTo(10, 14);
  }

  static void card(Path p) {
    p
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 5, 20, 14), const Radius.circular(3)))
      ..moveTo(2, 10)
      ..lineTo(22, 10);
  }

  static void person(Path p) {
    p
      ..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4))
      ..moveTo(4, 21)
      ..cubicTo(4, 17, 8, 15, 12, 15)
      ..cubicTo(16, 15, 20, 17, 20, 21);
  }

  static void store(Path p) {
    p
      ..moveTo(4, 9)
      ..lineTo(5, 4)
      ..lineTo(19, 4)
      ..lineTo(20, 9)
      ..moveTo(4, 9)
      ..lineTo(4, 19)
      ..quadraticBezierTo(4, 20, 5, 20)
      ..lineTo(19, 20)
      ..quadraticBezierTo(20, 20, 20, 19)
      ..lineTo(20, 9)
      ..moveTo(4, 9)
      ..lineTo(20, 9)
      ..moveTo(9, 20)
      ..lineTo(9, 14)
      ..lineTo(15, 14)
      ..lineTo(15, 20);
  }

  static void home(Path p) {
    p
      ..moveTo(3, 9.5)
      ..lineTo(12, 3)
      ..lineTo(21, 9.5)
      ..lineTo(21, 20)
      ..quadraticBezierTo(21, 21, 20, 21)
      ..lineTo(15, 21)
      ..lineTo(15, 15)
      ..lineTo(9, 15)
      ..lineTo(9, 21)
      ..lineTo(4, 21)
      ..quadraticBezierTo(3, 21, 3, 20)
      ..close();
  }

  static void bars(Path p) {
    p
      ..moveTo(4, 19)
      ..lineTo(4, 12)
      ..moveTo(10, 19)
      ..lineTo(10, 6)
      ..moveTo(16, 19)
      ..lineTo(16, 10)
      ..moveTo(22, 19)
      ..lineTo(22, 4);
  }

  static void logout(Path p) {
    p
      ..moveTo(9, 21)
      ..lineTo(5, 21)
      ..quadraticBezierTo(3, 21, 3, 19)
      ..lineTo(3, 5)
      ..quadraticBezierTo(3, 3, 5, 3)
      ..lineTo(9, 3)
      ..moveTo(16, 17)
      ..lineTo(21, 12)
      ..lineTo(16, 7)
      ..moveTo(21, 12)
      ..lineTo(9, 12);
  }

  static void check(Path p) {
    p
      ..moveTo(20, 6)
      ..lineTo(9, 17)
      ..lineTo(4, 12);
  }

  static void close(Path p) {
    p
      ..moveTo(6, 6)
      ..lineTo(18, 18)
      ..moveTo(18, 6)
      ..lineTo(6, 18);
  }

  static void backspace(Path p) {
    p
      ..moveTo(9, 4.5)
      ..lineTo(21, 4.5)
      ..quadraticBezierTo(22.5, 4.5, 22.5, 6)
      ..lineTo(22.5, 18)
      ..quadraticBezierTo(22.5, 19.5, 21, 19.5)
      ..lineTo(9, 19.5)
      ..lineTo(1.5, 12)
      ..close()
      ..moveTo(11.5, 9)
      ..lineTo(17.5, 15)
      ..moveTo(17.5, 9)
      ..lineTo(11.5, 15);
  }

  static void lock(Path p) {
    p
      ..moveTo(7, 10)
      ..lineTo(7, 7)
      ..arcToPoint(const Offset(17, 7), radius: const Radius.circular(5))
      ..lineTo(17, 10)
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 10, 16, 11), const Radius.circular(2)));
  }
}

/// The multicolor Google "G", approximated with arcs.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    canvas.scale(s, s);
    const c = Offset(10, 10);
    const r = 7.2;
    const sw = 3.4;
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;

    double rad(double deg) => deg * math.pi / 180;
    // Opening sits at the top-right; crossbar is blue.
    canvas.drawArc(rect, rad(0), rad(45), false, paint..color = const Color(0xFF4285F4));
    canvas.drawArc(rect, rad(45), rad(90), false, paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, rad(135), rad(80), false, paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, rad(215), rad(110), false, paint..color = const Color(0xFFEA4335));
    canvas.drawRect(
      Rect.fromLTRB(10, 10 - sw / 2, 10 + r + sw / 2, 10 + sw / 2),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}

// ---------------------------------------------------------------------------
// Animations
// ---------------------------------------------------------------------------

/// Expanding rings, like the design's `t-ripple` keyframes.
class Ripples extends StatefulWidget {
  const Ripples({
    super.key,
    required this.size,
    required this.color,
    this.count = 2,
    this.period = const Duration(milliseconds: 2400),
    this.strokeWidth = 2,
  });

  final double size;
  final Color color;
  final int count;
  final Duration period;
  final double strokeWidth;

  @override
  State<Ripples> createState() => _RipplesState();
}

class _RipplesState extends State<Ripples> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < widget.count; i++)
              _ring((_c.value + i / widget.count) % 1.0),
          ],
        );
      },
    );
  }

  Widget _ring(double t) {
    final e = Curves.easeOut.transform(t);
    final scale = lerpDouble(.35, 2, e)!;
    return Opacity(
      opacity: .5 * (1 - e),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}

/// Gentle vertical bob, like `t-float`.
class FloatY extends StatefulWidget {
  const FloatY({super.key, required this.child, this.amplitude = 9});

  final Widget child;
  final double amplitude;

  @override
  State<FloatY> createState() => _FloatYState();
}

class _FloatYState extends State<FloatY> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.amplitude / 2 * (1 - math.cos(2 * math.pi * _c.value))),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Pop-in scale, like `t-pop`.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) {
        final s = lerpDouble(.3, 1, Curves.easeOutBack.transform(t))!;
        return Opacity(
          opacity: (t * 1.8).clamp(0, 1).toDouble(),
          child: Transform.scale(scale: s, child: child),
        );
      },
      child: child,
    );
  }
}

/// Bottom-sheet slide-up, like `t-sheet`.
class SheetIn extends StatelessWidget {
  const SheetIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) =>
          FractionalTranslation(translation: Offset(0, t), child: child),
      child: child,
    );
  }
}

/// Fade-and-rise entrance, like `t-fade`.
class FadeUp extends StatelessWidget {
  const FadeUp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 44, this.strokeWidth = 4});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: .25),
      ),
    );
  }
}

/// Animated collect-progress ring. Pass [gradient] for a sweep-gradient stroke.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 168,
    this.strokeWidth = 14,
    this.track = T.ringTrack,
    this.fill = T.indigo,
    this.gradient,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color track;
  final Color fill;
  final List<Color>? gradient;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.fastOutSlowIn,
      builder: (context, value, child) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(value, strokeWidth, track, fill, gradient),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.strokeWidth, this.track, this.fill, this.gradient);

  final double value;
  final double strokeWidth;
  final Color track;
  final Color fill;
  final List<Color>? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, r, paint);
    if (value > 0) {
      paint.strokeCap = StrokeCap.round;
      if (gradient != null) {
        paint.shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: gradient!,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect);
      } else {
        paint.color = fill;
      }
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}

/// Spring-y press feedback: scales the child down slightly while held.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = .96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade-and-rise entrance with a start delay, for staggering list items.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> {
  bool _shown = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, .12),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Tabular figures so amounts/totals don't shift width as digits change.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
