import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/delivery_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ble_radar_pulse.dart';
import '../../shared/widgets/food_buddy_widget.dart';
import '../../shared/widgets/tactile_otp_keypad.dart';
import '../../shared/widgets/thermal_range_bar.dart';
import '../orders/order_detail_view.dart';

/// Flujo inmersivo de entrega activa M04 → M13 sin distracciones.
class ActiveDeliveryScreen extends StatefulWidget {
  final AppState appState;

  const ActiveDeliveryScreen({super.key, required this.appState});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  // M05 Escaneo BLE
  bool _scanningBle = false;
  List<BleDeviceInfo> _foundDevices = [];
  String? _connectingMac;

  // M08/M09 OTP
  String _otpInput = '';
  bool _otpError = false;
  String? _otpMessage;
  bool _verifyingOtp = false;
  bool _revealSupportOtp = false;

  // M11/M12 Cámara / Evidencia
  bool _submittingEvidence = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.appState.currentStep == DeliveryStep.bleConnect) {
      _runBleScan();
    }
  }

  @override
  void didUpdateWidget(covariant ActiveDeliveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appState.currentStep == DeliveryStep.bleConnect &&
        _foundDevices.isEmpty &&
        !_scanningBle) {
      _runBleScan();
    }
  }

  Future<void> _runBleScan() async {
    final order = widget.appState.currentOrder;
    if (order == null || _scanningBle) return;
    setState(() {
      _scanningBle = true;
      _foundDevices = [];
    });
    final devices = await widget.appState.gateway.scanForSmartBox(
      targetBoxId: order.smartBoxId,
      targetMac: order.smartBoxMac,
    );
    if (!mounted) return;
    setState(() {
      _scanningBle = false;
      _foundDevices = devices;
    });
  }

  Future<void> _connectBle(BleDeviceInfo device) async {
    setState(() => _connectingMac = device.macAddress);
    final ok = await widget.appState.connectSmartBoxDevice(device);
    if (!mounted) return;
    setState(() => _connectingMac = null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enlazar con la SmartBox. Reintenta.'),
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpInput.length < 6 || _verifyingOtp) return;
    setState(() {
      _verifyingOtp = true;
      _otpError = false;
      _otpMessage = null;
    });
    final res = await widget.appState.verifyOtpAndUnlock(_otpInput);
    if (!mounted) return;
    setState(() {
      _verifyingOtp = false;
      if (!res.success) {
        _otpError = true;
        _otpMessage = res.message;
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 78,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      widget.appState.stageCapturedPhoto(dataUrl);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cámara no disponible en este entorno. Usa la captura simulada.',
            ),
          ),
        );
      }
    }
  }

  void _captureSimulatedDemoPhoto() {
    // Pequeño PNG 1x1 válido codificado en base64 para flujo de prueba/emulador
    const demoPngDataUrl =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    widget.appState.stageCapturedPhoto(demoPngDataUrl);
  }

  Future<void> _submitEvidence() async {
    setState(() => _submittingEvidence = true);
    await widget.appState.submitStagedEvidenceAndFinish();
    if (!mounted) return;
    setState(() => _submittingEvidence = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.appState.currentOrder;
    if (order == null) return const SizedBox.shrink();
    final step = widget.appState.currentStep;
    final s = widget.appState.strings;

    final canGoBackToList =
        step == DeliveryStep.orderDetail || step == DeliveryStep.bleConnect;

    return Scaffold(
      backgroundColor:
          step == DeliveryStep.captureEvidence ? AppColors.navy : AppColors.bgAlt,
      appBar: AppBar(
        backgroundColor:
            step == DeliveryStep.captureEvidence ? AppColors.navy : AppColors.bg,
        foregroundColor:
            step == DeliveryStep.captureEvidence ? Colors.white : AppColors.ink,
        leading: step == DeliveryStep.completed
            ? null
            : IconButton(
                icon: Icon(
                  canGoBackToList
                      ? Icons.arrow_back_rounded
                      : Icons.close_rounded,
                ),
                onPressed: () {
                  if (step == DeliveryStep.otpUnlock) {
                    widget.appState.backToInTransit();
                  } else if (step == DeliveryStep.reviewEvidence) {
                    widget.appState.retakePhoto();
                  } else {
                    widget.appState.cancelDeliveryFlow();
                  }
                },
              ),
        title: Text(
          _stepTitle(step, s, order.id),
          style: TextStyle(
            color: step == DeliveryStep.captureEvidence
                ? Colors.white
                : AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: switch (step) {
          DeliveryStep.orderDetail => OrderDetailView(
              appState: widget.appState,
              order: order,
            ),
          DeliveryStep.bleConnect => _buildM05BleConnect(context, order),
          DeliveryStep.inTransit => _buildM06M07InTransit(context, order),
          DeliveryStep.otpUnlock => _buildM08M09Otp(context, order),
          DeliveryStep.boxUnlocked => _buildM10Unlocked(context, order),
          DeliveryStep.captureEvidence => _buildM11Camera(context),
          DeliveryStep.reviewEvidence => _buildM12Review(context, order),
          DeliveryStep.completed => _buildM13Completed(context, order),
        },
      ),
    );
  }

  String _stepTitle(DeliveryStep step, dynamic s, String orderId) {
    switch (step) {
      case DeliveryStep.orderDetail:
        return s.orderDetailTitle as String;
      case DeliveryStep.bleConnect:
        return s.bleConnectTitle as String;
      case DeliveryStep.inTransit:
        return orderId;
      case DeliveryStep.otpUnlock:
        return s.otpTitle as String;
      case DeliveryStep.boxUnlocked:
        return s.unlockedTitle as String;
      case DeliveryStep.captureEvidence:
        return s.cameraTitle as String;
      case DeliveryStep.reviewEvidence:
        return s.reviewTitle as String;
      case DeliveryStep.completed:
        return s.completedTitle as String;
    }
  }

  // M05: Radar BLE + Dispositivos cercanos
  Widget _buildM05BleConnect(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
            child: Column(
              children: [
                BleRadarPulse(scanning: _scanningBle),
                const SizedBox(height: 18),
                Text(
                  _scanningBle ? s.bleScanning : 'Dispositivos SmartBox detectados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Objetivo asignado: ${order.smartBoxId} (${order.smartBoxMac})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final dev in _foundDevices) ...[
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: dev.id == order.smartBoxId
                    ? AppColors.hotSoft
                    : AppColors.coldSoft,
                child: Icon(
                  Icons.sensors_rounded,
                  color: dev.id == order.smartBoxId
                      ? AppColors.hotStrong
                      : AppColors.coldStrong,
                ),
              ),
              title: Text(
                dev.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${dev.macAddress} · ${dev.rssi} dBm (~${dev.estimatedDistanceMeters.toStringAsFixed(1)} m)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: _connectingMac == dev.macAddress
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () => _connectBle(dev),
                      child: const Text('Enlazar'),
                    ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _scanningBle ? null : _runBleScan,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(s.bleRescan),
        ),
      ],
    );
  }

  // M06 + M07: Monitoreo en ruta + FoodBuddy + Barra de rango + Grid 3 cards + Simulador ESP32
  Widget _buildM06M07InTransit(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    final isHot = order.thermalMode == ThermalMode.hot;
    final tamper = order.tamperLevel;
    final distM = BleDeviceInfo(
      id: order.smartBoxId,
      name: order.smartBoxId,
      macAddress: order.smartBoxMac,
      rssi: widget.appState.lastRssi,
    ).estimatedDistanceMeters;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // M07 Banner de seguridad en dos niveles
        if (tamper != TamperAlertLevel.none) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: tamper == TamperAlertLevel.unauthorizedAccess
                  ? AppColors.danger
                  : AppColors.warnSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tamper == TamperAlertLevel.unauthorizedAccess
                    ? AppColors.dangerStrong
                    : AppColors.warnStrong,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: tamper == TamperAlertLevel.unauthorizedAccess
                      ? Colors.white
                      : AppColors.warnStrong,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tamper == TamperAlertLevel.unauthorizedAccess
                            ? s.alertTamperTitle
                            : s.alertLidOpenTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tamper == TamperAlertLevel.unauthorizedAccess
                              ? Colors.white
                              : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tamper == TamperAlertLevel.unauthorizedAccess
                            ? 'Tapa abierta sin OTP y paquete retirado de la caja.'
                            : 'El sensor magnético detectó apertura. Verifica el sello físico.',
                        style: TextStyle(
                          fontSize: 12,
                          color: tamper == TamperAlertLevel.unauthorizedAccess
                              ? Colors.white.withValues(alpha: 0.92)
                              : AppColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Pill de estado de ruta
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.okSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors_rounded,
                      size: 14, color: AppColors.okStrong),
                  const SizedBox(width: 6),
                  Text(
                    s.statusInRoute,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.okStrong,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Queue: ${widget.appState.offlineQueue.pendingCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tarjeta Hero Térmica con FoodBuddy animado + lectura DS18B20 + escala
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    FoodBuddyWidget(
                      category: order.foodCategory,
                      thermalMode: order.thermalMode,
                      currentTemp: order.currentTemp,
                      minTemp: order.targetMinTemp,
                      maxTemp: order.targetMaxTemp,
                      previousTemp: order.previousTemp,
                      size: 102,
                      language: widget.appState.language,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sensor DS18B20',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.currentTemp.toStringAsFixed(1)}°C',
                            style: AppTheme.displayNum(
                              fontSize: 42,
                              color: order.thermalStatus == ThermalStatus.breach
                                  ? AppColors.dangerStrong
                                  : (isHot
                                      ? AppColors.hotStrong
                                      : AppColors.coldStrong),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.customerAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ThermalRangeBar(
                  mode: order.thermalMode,
                  currentTemp: order.currentTemp,
                  minTemp: order.targetMinTemp,
                  maxTemp: order.targetMaxTemp,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Grid 3 tarjetas táctiles: Cerrojo / Batería / Enlace BLE
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: order.lockStatus == LockStatus.locked
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                label: s.lockLabel,
                value:
                    order.lockStatus == LockStatus.locked ? 'Cerrado' : 'Abierto',
                tint: order.lockStatus == LockStatus.locked
                    ? AppColors.okStrong
                    : AppColors.hotStrong,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.battery_charging_full_rounded,
                label: s.batteryLabel,
                value: '${order.batteryLevel}%',
                tint: order.batteryLevel < 20
                    ? AppColors.dangerStrong
                    : AppColors.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.bluetooth_connected_rounded,
                label: s.bleLinkLabel,
                value: '~${distM.toStringAsFixed(1)} m',
                tint: AppColors.coldStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Laboratorio Simulador ESP32
        Card(
          child: ExpansionTile(
            title: Text(
              s.simulatorTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                  ),
            ),
            subtitle: Text(
              'Prueba reacciones de la mascota y alertas en vivo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(isHot ? 'Óptimo (71°C)' : 'Óptimo (4°C / -12°C)'),
                    onPressed: () => widget.appState.simulateTemperature(
                      (order.targetMinTemp + order.targetMaxTemp) / 2,
                    ),
                  ),
                  ActionChip(
                    label: Text(
                      isHot ? 'Enfriar abajo (${(order.targetMinTemp - 6).toStringAsFixed(0)}°C)' : 'Subir calor (${(order.targetMaxTemp + 6).toStringAsFixed(0)}°C)',
                    ),
                    onPressed: () => widget.appState.simulateTemperature(
                      isHot
                          ? order.targetMinTemp - 6
                          : order.targetMaxTemp + 6,
                    ),
                  ),
                  ActionChip(
                    label: const Text('M07 Nivel 1 (Tapa abierta)'),
                    onPressed: () => widget.appState.simulateLidState(
                      lidOpen: true,
                      packagePresent: true,
                    ),
                  ),
                  ActionChip(
                    label: const Text('M07 Nivel 2 (Sin paquete)'),
                    onPressed: () => widget.appState.simulateLidState(
                      lidOpen: true,
                      packagePresent: false,
                    ),
                  ),
                  ActionChip(
                    label: const Text('Cerrar tapa'),
                    onPressed: () => widget.appState.simulateLidState(
                      lidOpen: false,
                      packagePresent: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          key: const Key('m06_arrive_otp_btn'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.hot),
          onPressed: widget.appState.proceedToOtpStep,
          icon: const Icon(Icons.pin_outlined),
          label: Text(s.arriveAndUnlock),
        ),
        ],
      ),
    );
  }

  // M08 / M09: OTP 6 dígitos + teclado táctil + intentos
  Widget _buildM08M09Otp(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.otpSub,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SmartBox ${order.smartBoxId} · Pedido ${order.id}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!widget.appState.backendOnline) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Demo OTP local: ${order.expectedOtp}',
                        style: AppTheme.mono(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    InkWell(
                      key: const Key('m08_reveal_otp_btn'),
                      onTap: () => setState(
                        () => _revealSupportOtp = !_revealSupportOtp,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          _revealSupportOtp
                              ? 'OTP de soporte (Backend): ${order.expectedOtp}'
                              : '¿En modo Demo? Toca aquí para ver OTP',
                          style: AppTheme.mono(
                            fontSize: 11.5,
                            color: AppColors.ink2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TactileOtpKeypad(
                    code: _otpInput,
                    hasError: _otpError,
                    attemptsUsed: widget.appState.otpAttempts,
                    enabled: !_verifyingOtp,
                    onDigit: (d) {
                      if (_otpInput.length >= 6) return;
                      setState(() {
                        _otpError = false;
                        _otpMessage = null;
                        _otpInput += d;
                      });
                    },
                    onBackspace: () {
                      if (_otpInput.isEmpty) return;
                      setState(() {
                        _otpError = false;
                        _otpMessage = null;
                        _otpInput =
                            _otpInput.substring(0, _otpInput.length - 1);
                      });
                    },
                    onClear: () {
                      setState(() {
                        _otpInput = '';
                        _otpError = false;
                        _otpMessage = null;
                      });
                    },
                  ),
                  if (_otpMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _otpMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.dangerStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('m08_unlock_btn'),
            onPressed:
                _otpInput.length == 6 && !_verifyingOtp ? _verifyOtp : null,
            child: _verifyingOtp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(s.unlockBtn),
          ),
        ],
      ),
    );
  }

  // M10: Confirmación SmartBox desbloqueada
  Widget _buildM10Unlocked(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.okSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.okStrong,
                size: 46,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            s.unlockedTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            s.unlockedSub,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Center(
            child: Image.asset(
              'assets/brand/smartbox.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            key: const Key('m10_take_photo_btn'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.okStrong),
            onPressed: widget.appState.proceedToCameraStep,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(s.takePhotoBtn),
          ),
        ],
      ),
    );
  }

  // M11: Visor de Cámara oscuro con guía punteada
  Widget _buildM11Camera(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF132033),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cold.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.center_focus_weak_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Encuadra el pedido entregado',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.hot),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capturar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('m11_demo_capture_btn'),
            onPressed: _captureSimulatedDemoPhoto,
            child: Text(
              'Usar captura rápida de prueba (Emulador / Demo)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
        ],
      ),
    );
  }

  // M12: Revisión de evidencia antes de cerrar custodia
  Widget _buildM12Review(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    final dataUrl = widget.appState.pendingEvidenceDataUrl ?? '';

    Widget preview = const SizedBox(
      height: 180,
      child: Center(
        child: Icon(Icons.image_rounded, size: 64, color: AppColors.muted),
      ),
    );
    if (dataUrl.startsWith('data:image')) {
      try {
        final b64 = dataUrl.split(',').last;
        preview = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            base64Decode(b64),
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (c, e, st) => const SizedBox(
              height: 180,
              child: Icon(Icons.check_circle_outline_rounded, size: 54),
            ),
          ),
        );
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(height: 14),
                      Text(
                        'Pedido ${order.id} · ${order.customerName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Temperatura registrada: ${order.currentTemp.toStringAsFixed(1)}°C',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submittingEvidence
                      ? null
                      : widget.appState.retakePhoto,
                  child: Text(s.retakeBtn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('m12_confirm_send_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.okStrong,
                  ),
                  onPressed: _submittingEvidence ? null : _submitEvidence,
                  child: _submittingEvidence
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(s.confirmSendBtn),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // M13: Entrega completada + resumen de auditoría
  Widget _buildM13Completed(BuildContext context, DeliveryOrder order) {
    final s = widget.appState.strings;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppColors.okSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.okStrong,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.completedTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            s.completedSub,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow('Pedido', order.id),
                  const Divider(color: AppColors.line, height: 18),
                  _SummaryRow(
                    'Temperatura final',
                    '${order.currentTemp.toStringAsFixed(1)}°C',
                  ),
                  const Divider(color: AppColors.line, height: 18),
                  _SummaryRow(
                    'Integridad',
                    order.thermalStatus == ThermalStatus.breach
                        ? 'Con alerta'
                        : 'Custodia intacta',
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('m13_finish_btn'),
            onPressed: widget.appState.finishCompletedView,
            child: Text(s.backToOrders),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: tint, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}
