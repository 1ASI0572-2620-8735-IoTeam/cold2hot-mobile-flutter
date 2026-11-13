import 'package:material_ui/material_ui.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';

/// Compuerta obligatoria post-login para asegurar permisos reales de hardware:
/// GPS / Ubicación en tiempo real (obligatorio), Bluetooth LE y Cámara.
class PermissionsGateScreen extends StatelessWidget {
  final AppState appState;

  const PermissionsGateScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final s = appState.strings;
    final p = appState.permissions;
    final gpsReady = p.locationServiceEnabled && p.locationGranted;

    return Scaffold(
      backgroundColor: AppColors.bgAlt,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.hotSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.hotStrong,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.permsTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 21,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(s.permsSub, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 22),
              _PermRow(
                icon: Icons.my_location_rounded,
                title: s.permGpsTitle,
                subtitle: s.permGpsDesc,
                granted: gpsReady,
                mandatory: true,
                statusText: !p.locationServiceEnabled
                    ? 'GPS Apagado'
                    : (p.locationGranted ? s.grantedTag : s.missingTag),
              ),
              const SizedBox(height: 12),
              _PermRow(
                icon: Icons.bluetooth_connected_rounded,
                title: s.permBleTitle,
                subtitle: s.permBleDesc,
                granted: p.bluetoothGranted,
                mandatory: false,
                statusText: p.bluetoothGranted ? s.grantedTag : s.missingTag,
              ),
              const SizedBox(height: 12),
              _PermRow(
                icon: Icons.photo_camera_outlined,
                title: s.permCamTitle,
                subtitle: s.permCamDesc,
                granted: p.cameraGranted,
                mandatory: false,
                statusText: p.cameraGranted ? s.grantedTag : s.missingTag,
              ),
              const Spacer(),
              if (!p.locationServiceEnabled) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    await appState.openGpsSettings();
                    await appState.refreshPermissionsStatus();
                  },
                  icon: const Icon(Icons.gps_fixed_rounded),
                  label: Text(s.enableGpsBtn),
                ),
                const SizedBox(height: 10),
              ],
              if (!gpsReady || !p.bluetoothGranted || !p.cameraGranted) ...[
                FilledButton.icon(
                  onPressed: p.locationForeverDenied
                      ? appState.openAppSettingsPage
                      : appState.requestDevicePermissions,
                  icon: const Icon(Icons.security_rounded),
                  label: Text(
                    p.locationForeverDenied
                        ? (s.isEs
                            ? 'Abrir ajustes de la app'
                            : 'Open app settings')
                        : s.grantPermsBtn,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (gpsReady)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.okStrong,
                  ),
                  onPressed: appState.continuePastPermissionsGate,
                  child: Text(s.continuePermsBtn),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool mandatory;
  final String statusText;

  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.mandatory,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: granted ? AppColors.okSoft : AppColors.bgAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: granted ? AppColors.okStrong : AppColors.ink2,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: granted
                              ? AppColors.okSoft
                              : (mandatory
                                  ? AppColors.dangerSoft
                                  : AppColors.warnSoft),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: granted
                                ? AppColors.okStrong
                                : (mandatory
                                    ? AppColors.dangerStrong
                                    : AppColors.warnStrong),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
