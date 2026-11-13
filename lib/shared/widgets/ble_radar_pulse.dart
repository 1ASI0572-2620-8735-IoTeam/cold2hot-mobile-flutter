import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';

/// Radar animado concéntrico para M05 (Emparejamiento BLE ESP32).
class BleRadarPulse extends StatefulWidget {
  final bool scanning;
  final Color color;

  const BleRadarPulse({
    super.key,
    required this.scanning,
    this.color = AppColors.coldStrong,
  });

  @override
  State<BleRadarPulse> createState() => _BleRadarPulseState();
}

class _BleRadarPulseState extends State<BleRadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.scanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BleRadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.scanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = widget.scanning ? _controller.value : 0.35;
          final t2 = (t + 0.5) % 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              _ring(t, 140),
              _ring(t2, 140),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double progress, double maxDiameter) {
    final size = 72 + (maxDiameter - 72) * progress;
    final opacity = (1.0 - progress).clamp(0.0, 0.35);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: opacity * 0.45),
        border: Border.all(
          color: widget.color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}
