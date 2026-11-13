import 'package:material_ui/material_ui.dart';
import '../../core/models/delivery_models.dart';
import '../../core/theme/app_theme.dart';

class LegalTermsSheet extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback? onAccept;

  const LegalTermsSheet({
    super.key,
    required this.language,
    this.onAccept,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AppLanguage language,
    bool showAcceptButton = true,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LegalTermsSheet(
        language: language,
        onAccept: showAcceptButton ? () => Navigator.of(ctx).pop(true) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = language == AppLanguage.es;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEs
                          ? 'Términos, Condiciones y Privacidad'
                          : 'Terms, Conditions & Privacy Policy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isEs
                    ? 'Cold2Hot IoT Logistics · Versión operativa v2.0'
                    : 'Cold2Hot IoT Logistics · Operational version v2.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _Section(
                      title: isEs
                          ? '1. Custodia térmica y telemetría IoT'
                          : '1. Thermal Custody & IoT Telemetry',
                      body: isEs
                          ? 'El operador acepta emparejar su dispositivo móvil vía Bluetooth Low Energy (BLE) con la SmartBox asignada para registrar continuamente lecturas de temperatura DS18B20, estado de tapa magnética y nivel de batería durante toda la ruta.'
                          : 'The courier agrees to pair their mobile device via Bluetooth Low Energy (BLE) with the assigned SmartBox to continuously record DS18B20 temperature readings, magnetic lid status, and battery level throughout the route.',
                    ),
                    _Section(
                      title: isEs
                          ? '2. Uso obligatorio de ubicación GPS en ruta'
                          : '2. Mandatory In-Route GPS Location Usage',
                      body: isEs
                          ? 'Cold2Hot recopila coordenadas GPS únicamente mientras tienes una sesión operativa iniciada o entregas activas en curso, con el fin de visualizar la ruta de entrega, correlacionar alertas térmicas con ubicación y respaldar auditorías del restaurante.'
                          : 'Cold2Hot collects GPS coordinates strictly while an operator session or active delivery is in progress, to display route guidance, correlate thermal alerts with location, and support restaurant audit trails.',
                    ),
                    _Section(
                      title: isEs
                          ? '3. Seguridad de apertura OTP y fotografía de entrega'
                          : '3. OTP Solenoid Security & Delivery Photo Proof',
                      body: isEs
                          ? 'El cerrojo solenoide solo puede abrirse mediante el código OTP de 6 dígitos validado por el cliente en destino. Cualquier apertura sin OTP queda auditada en el sistema. La fotografía de entrega se utiliza exclusivamente como constancia de entrega y cierra el ciclo de custodia.'
                          : 'The solenoid lock can only be unlocked using the customer-provided 6-digit OTP at the destination. Any unauthorized lid opening is logged. The delivery photograph is used strictly as proof of delivery and closes custody.',
                    ),
                    _Section(
                      title: isEs
                          ? '4. Protección de datos personales'
                          : '4. Personal Data Protection',
                      body: isEs
                          ? 'Tus credenciales, identificador de operador y trazas técnicas se transmiten bajo cifrado y se conservan según las políticas de retención de tu establecimiento afiliado. Puedes revocar permisos desde Perfil o ajustes de Android en cualquier momento.'
                          : 'Your credentials, operator ID, and technical logs are transmitted securely and retained according to your affiliated restaurant policies. You can revoke permissions from Profile or Android settings at any time.',
                    ),
                  ],
                ),
              ),
              if (onAccept != null) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onAccept,
                  child: Text(
                    isEs
                        ? 'Aceptar términos y continuar'
                        : 'Accept terms & continue',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
