import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/models/delivery_models.dart';
import '../../core/theme/app_theme.dart';

enum BuddyMood { idle, optimal, cooling, frozen, warming, melting }

/// Personaje vectorial animado de la comida según categoría y estado térmico.
/// - HOT enfriándose/bajo rango: tiembla, se torna azulado, ojos tiritando, cristales de escarcha.
/// - COLD calentándose/sobre rango: suda, gotas cayendo, charco derritiéndose, ondas de calor.
/// - Óptimo: ojos parpadeando felices, sonrisa cálida y vapor o destellos frescos.
class FoodBuddyWidget extends StatefulWidget {
  final FoodCategory category;
  final ThermalMode thermalMode;
  final double? currentTemp;
  final double minTemp;
  final double maxTemp;
  final double? previousTemp;
  final double size;
  final bool showCaption;
  final AppLanguage language;

  const FoodBuddyWidget({
    super.key,
    required this.category,
    required this.thermalMode,
    required this.currentTemp,
    required this.minTemp,
    required this.maxTemp,
    this.previousTemp,
    this.size = 84,
    this.showCaption = true,
    this.language = AppLanguage.es,
  });

  static BuddyMood computeMood({
    required ThermalMode mode,
    required double? currentTemp,
    required double minTemp,
    required double maxTemp,
    double? previousTemp,
  }) {
    if (currentTemp == null) return BuddyMood.idle;
    if (mode == ThermalMode.hot) {
      if (currentTemp < minTemp) return BuddyMood.frozen;
      final dropping = previousTemp != null && (currentTemp - previousTemp) <= -0.35;
      if (dropping || currentTemp <= minTemp + 2.5) return BuddyMood.cooling;
      return BuddyMood.optimal;
    } else {
      if (currentTemp > maxTemp) return BuddyMood.melting;
      final rising = previousTemp != null && (currentTemp - previousTemp) >= 0.35;
      if (rising || currentTemp >= maxTemp - 2.0) return BuddyMood.warming;
      return BuddyMood.optimal;
    }
  }

  @override
  State<FoodBuddyWidget> createState() => _FoodBuddyWidgetState();
}

class _FoodBuddyWidgetState extends State<FoodBuddyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = FoodBuddyWidget.computeMood(
      mode: widget.thermalMode,
      currentTemp: widget.currentTemp,
      minTemp: widget.minTemp,
      maxTemp: widget.maxTemp,
      previousTemp: widget.previousTemp,
    );
    final strings = AppStrings(widget.language);
    final stageBg = _stageBg(mood, widget.thermalMode);
    final stageBorder = _stageBorder(mood);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = MediaQuery.maybeOf(context)?.disableAnimations == true
                ? 0.0
                : _controller.value;

            double dx = 0;
            double dy = 0;
            double scaleX = 1.0;
            double scaleY = 1.0;

            if (mood == BuddyMood.frozen) {
              dx = math.sin(t * math.pi * 16) * 2.4;
              dy = math.cos(t * math.pi * 12) * 0.7;
            } else if (mood == BuddyMood.cooling) {
              dx = math.sin(t * math.pi * 10) * 1.3;
            } else if (mood == BuddyMood.melting) {
              final wave = math.sin(t * math.pi * 2);
              scaleX = 1.0 + wave * 0.045;
              scaleY = 1.0 - wave * 0.055;
              dy = (wave.abs()) * 2.0;
            } else if (mood == BuddyMood.warming) {
              dy = math.sin(t * math.pi * 4) * 1.4;
            } else if (mood == BuddyMood.optimal) {
              dy = math.sin(t * math.pi * 2) * 2.0;
            }

            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: stageBg,
                borderRadius: BorderRadius.circular(widget.size * 0.28),
                border: Border.all(color: stageBorder, width: 1.4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(
                  scaleX: scaleX,
                  scaleY: scaleY,
                  alignment: Alignment.bottomCenter,
                  child: CustomPaint(
                    painter: _FoodBuddyPainter(
                      category: widget.category,
                      thermalMode: widget.thermalMode,
                      mood: mood,
                      phase: t,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showCaption) ...[
          const SizedBox(height: 6),
          Text(
            strings.categoryLabel(widget.category),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            _moodLabel(mood, strings.isEs),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _moodTextColor(mood),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ],
      ],
    );
  }

  Color _stageBg(BuddyMood mood, ThermalMode mode) {
    if (mood == BuddyMood.frozen || mood == BuddyMood.cooling) {
      return AppColors.coldSoft;
    }
    if (mood == BuddyMood.melting || mood == BuddyMood.warming) {
      return AppColors.hotSoft;
    }
    return mode == ThermalMode.hot ? AppColors.hotSoft : AppColors.coldSoft;
  }

  Color _stageBorder(BuddyMood mood) {
    switch (mood) {
      case BuddyMood.frozen:
      case BuddyMood.cooling:
        return AppColors.coldStrong.withValues(alpha: 0.45);
      case BuddyMood.melting:
      case BuddyMood.warming:
        return AppColors.hot.withValues(alpha: 0.55);
      case BuddyMood.optimal:
      case BuddyMood.idle:
        return AppColors.line;
    }
  }

  Color _moodTextColor(BuddyMood mood) {
    switch (mood) {
      case BuddyMood.frozen:
      case BuddyMood.cooling:
        return AppColors.coldStrong;
      case BuddyMood.melting:
      case BuddyMood.warming:
        return AppColors.hotStrong;
      case BuddyMood.optimal:
        return AppColors.okStrong;
      case BuddyMood.idle:
        return AppColors.muted;
    }
  }

  String _moodLabel(BuddyMood mood, bool isEs) {
    switch (mood) {
      case BuddyMood.idle:
        return isEs ? 'Sin lectura' : 'No reading';
      case BuddyMood.optimal:
        return isEs ? 'Temperatura ideal' : 'Ideal temp';
      case BuddyMood.cooling:
        return isEs ? 'Enfriándose' : 'Cooling down';
      case BuddyMood.frozen:
        return isEs ? '¡Muy frío!' : 'Too cold!';
      case BuddyMood.warming:
        return isEs ? 'Calentándose' : 'Warming up';
      case BuddyMood.melting:
        return isEs ? '¡Derritiéndose!' : 'Melting!';
    }
  }
}

class _FoodBuddyPainter extends CustomPainter {
  final FoodCategory category;
  final ThermalMode thermalMode;
  final BuddyMood mood;
  final double phase;

  _FoodBuddyPainter({
    required this.category,
    required this.thermalMode,
    required this.mood,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120.0;
    canvas.save();
    canvas.scale(s, s);

    final inkStroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 1. Efectos ambientales superiores
    _paintAmbientTop(canvas);

    // 2. Charco si se está derritiendo
    if (mood == BuddyMood.melting) {
      final puddleScale = 0.92 + math.sin(phase * math.pi * 2) * 0.08;
      canvas.save();
      canvas.translate(60, 104);
      canvas.scale(puddleScale, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 68, height: 11),
        Paint()..color = const Color(0xFFFB923C).withValues(alpha: 0.45),
      );
      canvas.restore();
    }

    // 3. Cuerpo según categoría
    late final Offset faceCenter;
    switch (category) {
      case FoodCategory.burger:
        _paintBurger(canvas, inkStroke);
        faceCenter = const Offset(60, 73);
      case FoodCategory.pizza:
        _paintPizza(canvas, inkStroke);
        faceCenter = const Offset(60, 66);
      case FoodCategory.hotDrink:
        _paintHotDrink(canvas, inkStroke);
        faceCenter = const Offset(60, 71);
      case FoodCategory.iceCream:
        _paintIceCream(canvas, inkStroke);
        faceCenter = const Offset(60, 53);
      case FoodCategory.coldDrink:
        _paintColdDrink(canvas, inkStroke);
        faceCenter = const Offset(60, 73);
      case FoodCategory.sushi:
        _paintSushi(canvas, inkStroke);
        faceCenter = const Offset(60, 74);
    }

    // 4. Rostro expresivo (ojos + boca)
    _paintFace(canvas, faceCenter);

    // 5. Gotas cayendo si se calienta / derrite
    if (mood == BuddyMood.melting || mood == BuddyMood.warming) {
      _paintDripping(canvas);
    }

    canvas.restore();
  }

  void _paintAmbientTop(Canvas canvas) {
    if (thermalMode == ThermalMode.hot && mood == BuddyMood.optimal) {
      final p = Paint()
        ..color = AppColors.hot.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final offsetPhase = (phase + i * 0.33) % 1.0;
        final dy = 4 - offsetPhase * 10;
        final alpha = math.sin(offsetPhase * math.pi).clamp(0.0, 1.0);
        p.color = AppColors.hot.withValues(alpha: alpha * 0.8);
        final x = 40.0 + i * 20.0;
        final path = Path()
          ..moveTo(x, 22 + dy)
          ..cubicTo(x - 4, 15 + dy, x + 4, 11 + dy, x, 5 + dy);
        canvas.drawPath(path, p);
      }
    } else if (mood == BuddyMood.frozen || mood == BuddyMood.cooling) {
      final p = Paint()
        ..color = AppColors.coldStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (final center in const [Offset(22, 28), Offset(98, 24)]) {
        canvas.drawLine(Offset(center.dx, center.dy - 5), Offset(center.dx, center.dy + 5), p);
        canvas.drawLine(Offset(center.dx - 5, center.dy), Offset(center.dx + 5, center.dy), p);
        canvas.drawLine(Offset(center.dx - 3.5, center.dy - 3.5), Offset(center.dx + 3.5, center.dy + 3.5), p);
        canvas.drawLine(Offset(center.dx + 3.5, center.dy - 3.5), Offset(center.dx - 3.5, center.dy + 3.5), p);
      }
    } else if (thermalMode == ThermalMode.cold && mood == BuddyMood.optimal) {
      final p = Paint()..color = AppColors.coldStrong.withValues(alpha: 0.75);
      final scale = 0.8 + math.sin(phase * math.pi * 2) * 0.25;
      for (final pt in const [Offset(24, 24), Offset(95, 27)]) {
        canvas.drawCircle(pt, 3.0 * scale, p);
      }
    } else if (mood == BuddyMood.melting || mood == BuddyMood.warming) {
      final p = Paint()
        ..color = AppColors.hotStrong.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round;
      for (final x in const [25.0, 94.0]) {
        final dy = -((phase * 8) % 8);
        final path = Path()
          ..moveTo(x, 24 + dy)
          ..cubicTo(x - 4, 18 + dy, x + 4, 13 + dy, x, 8 + dy);
        canvas.drawPath(path, p);
      }
    }
  }

  void _paintBurger(Canvas canvas, Paint ink) {
    final bunColor = mood == BuddyMood.frozen
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFF59E0B);
    final bottomBunColor = mood == BuddyMood.frozen
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFFBBF24);

    // Pan superior
    final topBun = Path()
      ..moveTo(26, 56)
      ..cubicTo(26, 33, 94, 33, 94, 56)
      ..close();
    canvas.drawPath(topBun, Paint()..color = bunColor);
    canvas.drawPath(topBun, ink);

    // Semillas
    final seedPaint = Paint()..color = const Color(0xFFFEF3C7);
    canvas.drawOval(Rect.fromCenter(center: const Offset(44, 44), width: 5, height: 2.5), seedPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 40), width: 5, height: 2.5), seedPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(76, 44), width: 5, height: 2.5), seedPaint);

    // Lechuga
    final lettuce = Path()
      ..moveTo(23, 57)
      ..quadraticBezierTo(32, 63, 41, 57)
      ..quadraticBezierTo(50, 63, 60, 57)
      ..quadraticBezierTo(70, 63, 79, 57)
      ..quadraticBezierTo(88, 63, 97, 57);
    canvas.drawPath(
      lettuce,
      Paint()
        ..color = AppColors.ok
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Queso
    final cheese = Path()
      ..moveTo(26, 60)
      ..lineTo(94, 60)
      ..lineTo(89, 68)
      ..lineTo(74, 63)
      ..lineTo(62, 72)
      ..lineTo(48, 63)
      ..lineTo(31, 69)
      ..close();
    canvas.drawPath(cheese, Paint()..color = const Color(0xFFFACC15));
    canvas.drawPath(cheese, ink..strokeWidth = 2.0);

    // Carne
    final pattyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(25, 65, 70, 17),
      const Radius.circular(8.5),
    );
    canvas.drawRRect(pattyRect, Paint()..color = const Color(0xFF7C2D12));
    canvas.drawRRect(pattyRect, ink..strokeWidth = 2.5);

    // Pan inferior
    final bottomBun = Path()
      ..moveTo(28, 82)
      ..lineTo(92, 82)
      ..cubicTo(92, 95, 84, 98, 60, 98)
      ..cubicTo(36, 98, 28, 95, 28, 82)
      ..close();
    canvas.drawPath(bottomBun, Paint()..color = bottomBunColor);
    canvas.drawPath(bottomBun, ink);
  }

  void _paintPizza(Canvas canvas, Paint ink) {
    final cheeseColor = mood == BuddyMood.frozen
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFFACC15);

    // Triángulo queso
    final slice = Path()
      ..moveTo(25, 36)
      ..lineTo(95, 36)
      ..lineTo(60, 100)
      ..close();
    canvas.drawPath(slice, Paint()..color = cheeseColor);
    canvas.drawPath(slice, ink);

    // Borde dorado
    final crust = Path()
      ..moveTo(22, 34)
      ..quadraticBezierTo(60, 26, 98, 34)
      ..lineTo(94, 43)
      ..quadraticBezierTo(60, 36, 26, 43)
      ..close();
    canvas.drawPath(crust, Paint()..color = const Color(0xFFD97706));
    canvas.drawPath(crust, ink);

    // Pepperoni
    final pep = Paint()..color = const Color(0xFFEF4444);
    for (final pt in const [Offset(44, 52), Offset(76, 51), Offset(60, 81)]) {
      canvas.drawCircle(pt, 5.2, pep);
      canvas.drawCircle(pt, 5.2, ink..strokeWidth = 1.8);
    }
  }

  void _paintHotDrink(Canvas canvas, Paint ink) {
    final cupBody = mood == BuddyMood.frozen
        ? const Color(0xFFE0F2FE)
        : const Color(0xFFFFFBEB);

    // Tapa
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 34, 52, 10),
      const Radius.circular(4),
    );
    canvas.drawRRect(lid, Paint()..color = AppColors.ink);

    // Vaso
    final cup = Path()
      ..moveTo(36, 44)
      ..lineTo(84, 44)
      ..lineTo(78, 96)
      ..lineTo(42, 96)
      ..close();
    canvas.drawPath(cup, Paint()..color = cupBody);
    canvas.drawPath(cup, ink);

    // Banda térmica naranja
    final band = Path()
      ..moveTo(38.5, 58)
      ..lineTo(81.5, 58)
      ..lineTo(79.5, 83)
      ..lineTo(40.5, 83)
      ..close();
    canvas.drawPath(band, Paint()..color = AppColors.hot);
    canvas.drawPath(band, ink..strokeWidth = 2.0);
  }

  void _paintIceCream(Canvas canvas, Paint ink) {
    final scoopColor = mood == BuddyMood.melting
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFF472B6);

    // Cono waffle
    final cone = Path()
      ..moveTo(38, 63)
      ..lineTo(82, 63)
      ..lineTo(60, 102)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFFF59E0B));
    canvas.drawPath(cone, ink);

    // Bola helado
    final scoop = Path()
      ..addOval(Rect.fromCircle(center: const Offset(60, 50), radius: 24));
    canvas.drawPath(scoop, Paint()..color = scoopColor);
    canvas.drawPath(scoop, ink);

    // Cereza
    canvas.drawCircle(const Offset(60, 24), 5.5, Paint()..color = AppColors.hot);
    canvas.drawCircle(const Offset(60, 24), 5.5, ink..strokeWidth = 1.8);
  }

  void _paintColdDrink(Canvas canvas, Paint ink) {
    final liquidColor = mood == BuddyMood.warming || mood == BuddyMood.melting
        ? const Color(0xFFFDBA74)
        : const Color(0xFF7DD3FC);

    // Sorbete
    canvas.drawLine(
      const Offset(60, 42),
      const Offset(74, 18),
      Paint()
        ..color = AppColors.hot
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Vaso
    final cup = Path()
      ..moveTo(37, 44)
      ..lineTo(83, 44)
      ..lineTo(77, 97)
      ..lineTo(43, 97)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0xFFF0F9FF));
    final liquid = Path()
      ..moveTo(39.5, 56)
      ..lineTo(80.5, 56)
      ..lineTo(76, 95)
      ..lineTo(44, 95)
      ..close();
    canvas.drawPath(liquid, Paint()..color = liquidColor);
    canvas.drawPath(cup, ink);

    // Cubos de hielo
    final icePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(45, 58, 10, 10), const Radius.circular(2)),
      icePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(64, 60, 10, 10), const Radius.circular(2)),
      icePaint,
    );
  }

  void _paintSushi(Canvas canvas, Paint ink) {
    // Arroz base
    final rice = RRect.fromRectAndRadius(
      const Rect.fromLTWH(26, 56, 68, 36),
      const Radius.circular(14),
    );
    canvas.drawRRect(rice, Paint()..color = Colors.white);
    canvas.drawRRect(rice, ink);

    // Lámina salmón superior
    final salmon = Path()
      ..moveTo(24, 58)
      ..quadraticBezierTo(60, 38, 96, 58)
      ..quadraticBezierTo(96, 67, 60, 66)
      ..quadraticBezierTo(24, 67, 24, 58)
      ..close();
    canvas.drawPath(salmon, Paint()..color = const Color(0xFFFB7185));
    canvas.drawPath(salmon, ink);

    // Cinta nori lateral
    canvas.drawRect(
      const Rect.fromLTWH(52, 56, 16, 36),
      Paint()..color = AppColors.ink,
    );
  }

  void _paintFace(Canvas canvas, Offset c) {
    final eyePaint = Paint()..color = AppColors.ink;
    final blushColor = mood == BuddyMood.frozen
        ? const Color(0xFF38BDF8)
        : (category == FoodCategory.hotDrink || category == FoodCategory.sushi
            ? Colors.white
            : AppColors.ink);

    final useLightInk =
        category == FoodCategory.hotDrink || category == FoodCategory.sushi;
    final strokePaint = Paint()
      ..color = useLightInk ? Colors.white : AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillInk = Paint()..color = useLightInk ? Colors.white : AppColors.ink;

    // Parpadeo natural cuando está óptimo
    final blink = mood == BuddyMood.optimal && (phase > 0.92 && phase < 0.97);

    // Ojos
    for (final side in const [-11.5, 11.5]) {
      final ex = c.dx + side;
      final ey = c.dy - 2.5;
      if (mood == BuddyMood.melting) {
        // Ojos espiral/aturdidos (> <)
        final sign = side < 0 ? 1.0 : -1.0;
        final p = Path()
          ..moveTo(ex - 3 * sign, ey - 3)
          ..lineTo(ex + 3 * sign, ey)
          ..lineTo(ex - 3 * sign, ey + 3);
        canvas.drawPath(p, strokePaint);
      } else if (blink) {
        canvas.drawLine(Offset(ex - 3.5, ey), Offset(ex + 3.5, ey), strokePaint);
      } else {
        canvas.drawCircle(Offset(ex, ey), 3.3, fillInk);
        canvas.drawCircle(
          Offset(ex - 1, ey - 1),
          1.1,
          Paint()..color = useLightInk ? AppColors.ink : Colors.white,
        );
      }
    }

    // Mejillas frescas/tibias en estado óptimo
    if (mood == BuddyMood.optimal) {
      final cheek = Paint()..color = blushColor.withValues(alpha: 0.16);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - 17, c.dy + 2), width: 6, height: 3.5), cheek);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + 17, c.dy + 2), width: 6, height: 3.5), cheek);
    }

    // Boca según mood térmico
    if (mood == BuddyMood.optimal) {
      final smile = Path()
        ..moveTo(c.dx - 7, c.dy + 3.5)
        ..quadraticBezierTo(c.dx, c.dy + 10.5, c.dx + 7, c.dy + 3.5);
      canvas.drawPath(smile, strokePaint);
    } else if (mood == BuddyMood.frozen) {
      // Boca temblando en zig-zag
      final chatter = Path()
        ..moveTo(c.dx - 8, c.dy + 5)
        ..lineTo(c.dx - 4, c.dy + 2.5)
        ..lineTo(c.dx, c.dy + 6)
        ..lineTo(c.dx + 4, c.dy + 2.5)
        ..lineTo(c.dx + 8, c.dy + 5);
      canvas.drawPath(chatter, strokePaint);
    } else if (mood == BuddyMood.cooling || mood == BuddyMood.warming) {
      // Boca ondulada preocupada
      final worried = Path()
        ..moveTo(c.dx - 6.5, c.dy + 6)
        ..quadraticBezierTo(c.dx, c.dy + 2, c.dx + 6.5, c.dy + 6);
      canvas.drawPath(worried, strokePaint);
    } else if (mood == BuddyMood.melting) {
      // Boca abierta agotada por calor
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 5.5), width: 10, height: 7),
        eyePaint,
      );
    } else {
      // Idle neutral
      canvas.drawLine(
        Offset(c.dx - 5, c.dy + 5),
        Offset(c.dx + 5, c.dy + 5),
        strokePaint,
      );
    }
  }

  void _paintDripping(Canvas canvas) {
    final dropPaint = Paint()..color = const Color(0xFFFB923C);
    for (int i = 0; i < 2; i++) {
      final p = (phase + i * 0.45) % 1.0;
      final x = i == 0 ? 34.0 : 86.0;
      final y = 62.0 + p * 22.0;
      final opacity = (1.0 - p).clamp(0.0, 0.9);
      dropPaint.color = const Color(0xFFFB923C).withValues(alpha: opacity);
      final drop = Path()
        ..moveTo(x, y - 4)
        ..quadraticBezierTo(x + 4, y + 3, x, y + 6)
        ..quadraticBezierTo(x - 4, y + 3, x, y - 4)
        ..close();
      canvas.drawPath(drop, dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FoodBuddyPainter oldDelegate) {
    return oldDelegate.category != category ||
        oldDelegate.thermalMode != thermalMode ||
        oldDelegate.mood != mood ||
        oldDelegate.phase != phase;
  }
}
