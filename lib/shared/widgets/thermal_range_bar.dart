import 'package:material_ui/material_ui.dart';
import '../../core/models/delivery_models.dart';
import '../../core/theme/app_theme.dart';

/// Escala visual horizontal que muestra el rango objetivo dentro del espectro
/// térmico y la posición en tiempo real de la lectura DS18B20.
class ThermalRangeBar extends StatelessWidget {
  final ThermalMode mode;
  final double currentTemp;
  final double minTemp;
  final double maxTemp;

  const ThermalRangeBar({
    super.key,
    required this.mode,
    required this.currentTemp,
    required this.minTemp,
    required this.maxTemp,
  });

  @override
  Widget build(BuildContext context) {
    final scaleMin = mode == ThermalMode.hot
        ? (minTemp - 18).clamp(0.0, 50.0)
        : (minTemp - 8).clamp(-30.0, 0.0);
    final scaleMax = mode == ThermalMode.hot
        ? (maxTemp + 10).clamp(70.0, 100.0)
        : (maxTemp + 14).clamp(10.0, 30.0);
    final span = (scaleMax - scaleMin).abs() < 1 ? 1.0 : (scaleMax - scaleMin);

    double pct(double v) => ((v - scaleMin) / span).clamp(0.0, 1.0);

    final safeStart = pct(minTemp);
    final safeEnd = pct(maxTemp);
    final markerPct = pct(currentTemp);
    final inRange = currentTemp >= minTemp && currentTemp <= maxTemp;
    final activeColor = !inRange
        ? AppColors.danger
        : (mode == ThermalMode.hot ? AppColors.hot : AppColors.coldStrong);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final leftSafe = safeStart * width;
            final widthSafe = ((safeEnd - safeStart) * width).clamp(12.0, width);
            final markerLeft = (markerPct * width).clamp(6.0, width - 6.0) - 6;

            return SizedBox(
              height: 26,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.bgAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line),
                    ),
                  ),
                  Positioned(
                    left: leftSafe,
                    width: widthSafe,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: mode == ThermalMode.hot
                            ? AppColors.hotSoft
                            : AppColors.coldSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: mode == ThermalMode.hot
                              ? AppColors.hot.withValues(alpha: 0.45)
                              : AppColors.coldStrong.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: 12,
                      height: 22,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Min ${minTemp.toStringAsFixed(0)}°C',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              inRange
                  ? 'Rango óptimo (${minTemp.toStringAsFixed(0)}–${maxTemp.toStringAsFixed(0)}°C)'
                  : 'Fuera de rango autorizado',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: inRange ? AppColors.okStrong : AppColors.dangerStrong,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              'Max ${maxTemp.toStringAsFixed(0)}°C',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
