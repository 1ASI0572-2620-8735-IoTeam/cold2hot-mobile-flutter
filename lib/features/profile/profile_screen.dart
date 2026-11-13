import 'package:material_ui/material_ui.dart';
import '../../core/config/api_config.dart';
import '../../core/models/delivery_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/legal_terms_sheet.dart';

/// M15 Perfil y Ajustes del Repartidor: idioma ES/EN, permisos hardware,
/// cola Offline Store-and-Forward, servidor API Gateway y Términos Legales.
class ProfileScreen extends StatelessWidget {
  final AppState appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    final s = appState.strings;
    final perms = appState.permissions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.ink,
                  child: Text(
                    user?.initials ?? 'OP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Operador',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.restaurantName ?? ''} · ${user?.role ?? 'OPERATOR'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.hotStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Idioma ES / EN
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.translate_rounded, color: AppColors.ink2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.isEs ? 'Idioma de la app' : 'App language',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<AppLanguage>(
                  segments: const [
                    ButtonSegment(value: AppLanguage.es, label: Text('ES')),
                    ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                  ],
                  selected: {appState.language},
                  onSelectionChanged: (set) =>
                      appState.setLanguage(set.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Permisos GPS / BLE / Cámara
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.isEs ? 'Sensores y permisos' : 'Hardware & permissions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _PermChipRow(
                  label: 'GPS (${perms.allRequiredGranted ? 'Activo' : 'Pendiente'})',
                  ok: perms.allRequiredGranted,
                ),
                const SizedBox(height: 6),
                _PermChipRow(
                  label: 'Bluetooth LE (${perms.bluetoothGranted ? 'Activo' : 'Pendiente'})',
                  ok: perms.bluetoothGranted,
                ),
                const SizedBox(height: 6),
                _PermChipRow(
                  label: 'Cámara (${perms.cameraGranted ? 'Activa' : 'Pendiente'})',
                  ok: perms.cameraGranted,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: appState.requestDevicePermissions,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    s.isEs ? 'Verificar permisos' : 'Check permissions',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Cola Store-and-Forward
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.sync_rounded, color: AppColors.coldStrong),
            title: Text(s.offlineQueueTitle),
            subtitle: Text(
              'Pendientes: ${appState.offlineQueue.pendingCount} paquetes',
            ),
            trailing: TextButton(
              onPressed: appState.flushOfflineQueue,
              child: const Text('Sincronizar'),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Términos y Condiciones
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const Icon(Icons.gavel_rounded, color: AppColors.ink2),
            title: Text(s.termsLink),
            subtitle: Text(
              appState.termsAccepted
                  ? (s.isEs ? 'Aceptados' : 'Accepted')
                  : (s.isEs ? 'Pendiente' : 'Pending'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => LegalTermsSheet.show(
              context,
              language: appState.language,
              showAcceptButton: false,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Backend API Gateway URL
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'API Gateway',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      appState.backendOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: appState.backendOnline
                            ? AppColors.okStrong
                            : AppColors.warnStrong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  appState.baseUrl,
                  style: AppTheme.mono(fontSize: 11.5, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Render'),
                      onPressed: () =>
                          appState.updateBaseUrl(ApiConfig.renderUrl),
                    ),
                    ActionChip(
                      label: const Text('10.0.2.2'),
                      onPressed: () =>
                          appState.updateBaseUrl(ApiConfig.androidEmulatorUrl),
                    ),
                    ActionChip(
                      label: const Text('Localhost'),
                      onPressed: () =>
                          appState.updateBaseUrl(ApiConfig.webLocalUrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dangerStrong,
            side: const BorderSide(color: AppColors.danger),
          ),
          onPressed: appState.logout,
          icon: const Icon(Icons.logout_rounded),
          label: Text(s.logoutBtn),
        ),
      ],
    );
  }
}

class _PermChipRow extends StatelessWidget {
  final String label;
  final bool ok;

  const _PermChipRow({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 18,
          color: ok ? AppColors.okStrong : AppColors.warnStrong,
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
