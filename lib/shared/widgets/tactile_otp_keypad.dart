import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';

/// Widget OTP táctil M08 / M09 con 6 casillas individuales, contador de intentos
/// y teclado numérico limpio de alto contraste integrado.
class TactileOtpKeypad extends StatelessWidget {
  final String code;
  final bool hasError;
  final int attemptsUsed;
  final int maxAttempts;
  final bool enabled;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const TactileOtpKeypad({
    super.key,
    required this.code,
    required this.hasError,
    required this.attemptsUsed,
    this.maxAttempts = 3,
    this.enabled = true,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (maxAttempts - attemptsUsed).clamp(0, maxAttempts);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (idx) {
            final filled = idx < code.length;
            final isActive = idx == code.length && !hasError;
            final char = filled ? code[idx] : '';
            final borderColor = hasError
                ? AppColors.danger
                : (isActive ? AppColors.ink : (filled ? AppColors.ink2 : AppColors.line));
            final bgColor = hasError
                ? AppColors.dangerSoft
                : (filled ? AppColors.bg : AppColors.bgAlt);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: (hasError || isActive) ? 2 : 1.2,
                ),
              ),
              child: Text(
                char,
                style: AppTheme.mono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: hasError ? AppColors.dangerStrong : AppColors.ink,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasError ? Icons.error_outline_rounded : Icons.lock_clock_outlined,
              size: 16,
              color: hasError ? AppColors.dangerStrong : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              'Intentos restantes: $remaining de $maxAttempts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasError ? AppColors.dangerStrong : AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['C', '0', 'BACK'],
        ]) ...[
          Row(
            children: [
              for (int i = 0; i < row.length; i++) ...[
                Expanded(child: _buildKey(context, row[i])),
                if (i < row.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildKey(BuildContext context, String value) {
    final isAction = value == 'C' || value == 'BACK';
    return Material(
      color: isAction ? AppColors.bgAlt : AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: !enabled
            ? null
            : () {
                if (value == 'C') {
                  onClear();
                } else if (value == 'BACK') {
                  onBackspace();
                } else {
                  onDigit(value);
                }
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: value == 'BACK'
              ? const Icon(Icons.backspace_outlined, size: 20, color: AppColors.ink)
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: value == 'C' ? 15 : 20,
                    fontWeight: FontWeight.w600,
                    color: value == 'C' ? AppColors.muted : AppColors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}
