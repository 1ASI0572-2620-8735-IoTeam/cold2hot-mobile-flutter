import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../i18n/app_strings.dart';
import '../iot/ble_gatt_gateway.dart';
import '../iot/offline_sync_queue.dart';
import '../models/delivery_models.dart';
import '../services/api_service.dart';
import '../services/permission_location_service.dart';

class AppState extends ChangeNotifier {
  static const _keyUser = 'c2h_mobile_user';
  static const _keyBaseUrl = 'c2h_mobile_base_url';
  static const _keyTerms = 'c2h_terms_accepted_v1';
  static const _keyLang = 'c2h_app_lang';

  final bool enablePlatformPlugins;

  late final ApiService _api;
  final BleGattGateway gateway = BleGattGateway();
  late final OfflineSyncQueue offlineQueue;
  final PermissionLocationService _permService = PermissionLocationService();

  OperatorUser? _user;
  String _baseUrl = ApiConfig.defaultBaseUrl;
  bool _backendOnline = false;
  bool _isLoading = false;
  bool _termsAccepted = false;
  bool _permissionsGatePassed = false;
  AppLanguage _language = AppLanguage.es;
  DevicePermissionsStatus _permissions = const DevicePermissionsStatus();
  GeoPoint? _currentGps;

  List<DeliveryOrder> _activeOrders = [];
  List<DeliveryOrder> _historyOrders = [];

  DeliveryOrder? _currentOrder;
  DeliveryStep _currentStep = DeliveryStep.orderDetail;
  BleDeviceInfo? _connectedDevice;
  int _lastRssi = -54;
  int _otpAttempts = 0;
  String? _pendingEvidenceDataUrl;

  Timer? _syncTimer;
  StreamSubscription<TelemetryPacket>? _bleSub;
  StreamSubscription<GeoPoint>? _gpsSub;

  OperatorUser? get user => _user;
  String get baseUrl => _baseUrl;
  bool get backendOnline => _backendOnline;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get termsAccepted => _termsAccepted;
  bool get permissionsGatePassed => _permissionsGatePassed;
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings(_language);
  DevicePermissionsStatus get permissions => _permissions;
  GeoPoint? get currentGps => _currentGps;

  List<DeliveryOrder> get activeOrders => List.unmodifiable(_activeOrders);
  List<DeliveryOrder> get historyOrders => List.unmodifiable(_historyOrders);
  DeliveryOrder? get currentOrder => _currentOrder;
  DeliveryStep get currentStep => _currentStep;
  BleDeviceInfo? get connectedDevice => _connectedDevice;
  int get lastRssi => _lastRssi;
  int get otpAttempts => _otpAttempts;
  String? get pendingEvidenceDataUrl => _pendingEvidenceDataUrl;

  AppState({this.enablePlatformPlugins = true}) {
    offlineQueue = OfflineSyncQueue(persistToDisk: enablePlatformPlugins);
    _api = ApiService(
      baseUrl: _baseUrl,
      offlineDemoOnly: !enablePlatformPlugins,
    );
    if (enablePlatformPlugins) {
      _init();
    } else {
      // Para widget tests limpios sin plugins nativos ni timers abiertos
      _seedDemoOrdersForTest();
    }
  }

  void _seedDemoOrdersForTest() {
    _permissions = const DevicePermissionsStatus(
      locationServiceEnabled: true,
      locationGranted: true,
      bluetoothGranted: true,
      cameraGranted: true,
    );
    _permissionsGatePassed = true;
    _activeOrders = [];
    _historyOrders = [];
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      _api.baseUrl = savedUrl;
    }

    _termsAccepted = prefs.getBool(_keyTerms) ?? false;
    final langRaw = prefs.getString(_keyLang);
    if (langRaw == 'en') _language = AppLanguage.en;

    final savedUser = prefs.getString(_keyUser);
    if (savedUser != null) {
      try {
        final json = jsonDecode(savedUser) as Map<String, dynamic>;
        _user = OperatorUser.fromJson(json, (json['token'] ?? '').toString());
        _api.authToken = _user!.token;
      } catch (_) {}
    }

    await offlineQueue.init();
    await refreshPermissionsStatus(autoPassIfGranted: true);
    await refreshBackendHealth();
    if (_user != null) {
      await loadOrders();
      await flushOfflineQueue();
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    notifyListeners();
    if (enablePlatformPlugins) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLang, lang == AppLanguage.en ? 'en' : 'es');
    }
  }

  Future<void> setTermsAccepted(bool accepted) async {
    _termsAccepted = accepted;
    notifyListeners();
    if (enablePlatformPlugins) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTerms, accepted);
    }
  }

  Future<void> refreshPermissionsStatus({bool autoPassIfGranted = false}) async {
    if (!enablePlatformPlugins) return;
    _permissions = await _permService.checkStatus();
    if (autoPassIfGranted && _permissions.allRequiredGranted) {
      _permissionsGatePassed = true;
      await _startGpsTracking();
    }
    notifyListeners();
  }

  Future<void> requestDevicePermissions() async {
    if (!enablePlatformPlugins) return;
    _permissions = await _permService.requestAll();
    if (_permissions.allRequiredGranted) {
      await _startGpsTracking();
    }
    notifyListeners();
  }

  Future<void> openGpsSettings() => _permService.openDeviceLocationSettings();
  Future<void> openAppSettingsPage() => _permService.openAppPermissionsSettings();

  void continuePastPermissionsGate() {
    _permissionsGatePassed = true;
    notifyListeners();
  }

  Future<void> _startGpsTracking() async {
    final pos = await _permService.getCurrentLocation();
    if (pos != null) {
      _currentGps = pos;
      notifyListeners();
    }
    await _gpsSub?.cancel();
    _gpsSub = _permService.watchLocation().listen((pt) {
      _currentGps = pt;
      notifyListeners();
    });
  }

  Future<void> refreshBackendHealth() async {
    _backendOnline = await _api.checkHealth();
    notifyListeners();
  }

  Future<void> updateBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = clean;
    _api.baseUrl = clean;
    if (enablePlatformPlugins) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBaseUrl, clean);
    }
    await refreshBackendHealth();
  }

  Future<ApiResponse<OperatorUser>> login(
    String email,
    String password, {
    required bool acceptedTerms,
  }) async {
    if (!acceptedTerms) {
      return ApiResponse(
        success: false,
        fromBackend: false,
        message: strings.termsRequiredError,
      );
    }

    await setTermsAccepted(true);
    _isLoading = true;
    notifyListeners();

    final res = await _api.login(email.trim(), password);
    if (res.success && res.data != null) {
      _user = res.data;
      _api.authToken = _user!.token;
      _backendOnline = res.fromBackend;
      if (enablePlatformPlugins) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(_user!.toJson()));
        await refreshPermissionsStatus(autoPassIfGranted: true);
      }
      await loadOrders();
      await flushOfflineQueue();
    }

    _isLoading = false;
    notifyListeners();
    return res;
  }

  Future<ApiResponse<OperatorUser>> loginDemo({
    required bool acceptedTerms,
  }) {
    return login(
      'admin@mirestaurante.pe',
      'password123',
      acceptedTerms: acceptedTerms,
    );
  }

  Future<ApiResponse<void>> forgotPassword(String email) {
    return _api.forgotPassword(email.trim());
  }

  Future<void> logout() async {
    _stopSyncLoop();
    unawaited(_bleSub?.cancel());
    _bleSub = null;
    unawaited(_gpsSub?.cancel());
    _gpsSub = null;
    unawaited(gateway.disconnect());
    _user = null;
    _api.authToken = null;
    _currentOrder = null;
    _connectedDevice = null;
    _pendingEvidenceDataUrl = null;
    _otpAttempts = 0;
    if (enablePlatformPlugins) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
    }
    notifyListeners();
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    final res = await _api.fetchOrdersBundle();
    if (res.success && res.data != null) {
      _activeOrders = res.data!.active;
      _historyOrders = res.data!.history;
      if (res.fromBackend) _backendOnline = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createDemoOrder() async {
    _isLoading = true;
    notifyListeners();
    final res = await _api.createDemoOrderOnBackend();
    if (res.success && res.data != null) {
      if (res.fromBackend) {
        _backendOnline = true;
        await loadOrders();
      } else {
        _activeOrders = [res.data!, ..._activeOrders];
        _isLoading = false;
        notifyListeners();
      }
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  void openOrderDetail(DeliveryOrder order) {
    _currentOrder = order;
    _currentStep = DeliveryStep.orderDetail;
    _connectedDevice = null;
    _pendingEvidenceDataUrl = null;
    _otpAttempts = 0;
    notifyListeners();
  }

  void proceedToBleScan() {
    _currentStep = DeliveryStep.bleConnect;
    notifyListeners();
  }

  void cancelDeliveryFlow() {
    _stopSyncLoop();
    unawaited(_bleSub?.cancel());
    _bleSub = null;
    unawaited(gateway.disconnect());
    _currentOrder = null;
    _connectedDevice = null;
    _pendingEvidenceDataUrl = null;
    _otpAttempts = 0;
    notifyListeners();
  }

  Future<bool> connectSmartBoxDevice(BleDeviceInfo device) async {
    final order = _currentOrder;
    if (order == null) return false;

    final ok = await gateway.connectToDevice(
      device,
      initialTemp: order.currentTemp,
      initialBattery: order.batteryLevel,
      initialLock: order.lockStatus,
      mode: order.thermalMode,
    );
    if (!ok) return false;

    _connectedDevice = device;
    _lastRssi = device.rssi;
    _currentOrder = order.copyWith(status: 'IN_TRANSIT');
    _currentStep = DeliveryStep.inTransit;

    unawaited(_bleSub?.cancel());
    _bleSub = gateway.telemetryStream.listen(_handleIncomingBlePacket);
    _startSyncLoop();
    notifyListeners();
    return true;
  }

  void _handleIncomingBlePacket(TelemetryPacket packet) {
    final order = _currentOrder;
    if (order == null) return;

    final prev = order.currentTemp;
    final nextHistory = List<TelemetryPoint>.from(order.history)
      ..add(TelemetryPoint(timestamp: packet.timestamp, temperature: packet.temperature));
    if (nextHistory.length > 24) {
      nextHistory.removeAt(0);
    }

    final lidChangedToOpen = !order.lidOpen && packet.lidOpen;

    _lastRssi = packet.rssi;
    _currentOrder = order.copyWith(
      previousTemp: prev,
      currentTemp: packet.temperature,
      batteryLevel: packet.batteryLevel,
      lockStatus: packet.lockStatus,
      lidOpen: packet.lidOpen,
      packagePresent: packet.packagePresent,
      history: nextHistory,
    );
    notifyListeners();

    if (lidChangedToOpen) {
      _dispatchTamper(
        orderId: order.cleanOrderId,
        smartBoxId: order.smartBoxId,
        lidOpen: packet.lidOpen,
        packagePresent: packet.packagePresent,
      );
    }
  }

  void proceedToOtpStep() {
    _otpAttempts = 0;
    _currentStep = DeliveryStep.otpUnlock;
    notifyListeners();
  }

  void backToInTransit() {
    _currentStep = DeliveryStep.inTransit;
    notifyListeners();
  }

  Future<ApiResponse<void>> verifyOtpAndUnlock(String otpCode) async {
    final order = _currentOrder;
    if (order == null) {
      return const ApiResponse(
        success: false,
        fromBackend: false,
        message: 'No hay pedido activo.',
      );
    }

    final res = await _api.validateOtpAndUnlock(
      orderId: order.cleanOrderId,
      smartBoxId: order.smartBoxId,
      otpCode: otpCode,
      expectedDemoOtp: order.expectedOtp,
    );

    if (res.success) {
      await gateway.writeSolenoidUnlock(otpCode);
      _currentOrder = order.copyWith(
        lockStatus: LockStatus.unlocked,
        lidOpen: false,
      );
      _currentStep = DeliveryStep.boxUnlocked;
      notifyListeners();
    } else {
      _otpAttempts++;
      notifyListeners();
    }
    return res;
  }

  void proceedToCameraStep() {
    _currentStep = DeliveryStep.captureEvidence;
    notifyListeners();
  }

  void stageCapturedPhoto(String dataUrlOrPath) {
    _pendingEvidenceDataUrl = dataUrlOrPath;
    _currentStep = DeliveryStep.reviewEvidence;
    notifyListeners();
  }

  void retakePhoto() {
    _pendingEvidenceDataUrl = null;
    _currentStep = DeliveryStep.captureEvidence;
    notifyListeners();
  }

  Future<ApiResponse<void>> submitStagedEvidenceAndFinish() async {
    final order = _currentOrder;
    final evidence = _pendingEvidenceDataUrl;
    if (order == null || evidence == null) {
      return const ApiResponse(
        success: false,
        fromBackend: false,
        message: 'Falta fotografía de evidencia.',
      );
    }

    final res = await _api.submitEvidence(
      orderId: order.cleanOrderId,
      photoBase64OrUrl: evidence,
    );

    if (!res.fromBackend) {
      await offlineQueue.enqueue('evidence', {
        'orderId': order.cleanOrderId,
        'photoBase64OrUrl': evidence,
      });
    }

    _stopSyncLoop();
    unawaited(_bleSub?.cancel());
    _bleSub = null;

    final completed = order.copyWith(
      status: 'DELIVERED',
      evidencePath: evidence,
      deliveredAt: DateTime.now(),
      packagePresent: false,
    );

    _activeOrders.removeWhere((o) => o.id == completed.id);
    _historyOrders.insert(0, completed);
    _currentOrder = completed;
    _currentStep = DeliveryStep.completed;
    notifyListeners();
    return res;
  }

  Future<void> finishCompletedView() async {
    await gateway.disconnect();
    _currentOrder = null;
    _connectedDevice = null;
    _pendingEvidenceDataUrl = null;
    notifyListeners();
  }

  /// Simulador de eventos ciberfísicos ESP32
  Future<void> simulateTemperature(double newTemp) async {
    final order = _currentOrder;
    if (order == null) return;
    gateway.injectSimulatedTelemetry(temperature: newTemp);
    await _dispatchTelemetry(
      smartBoxId: order.smartBoxId,
      orderId: order.cleanOrderId,
      temperature: newTemp,
      lidOpen: order.lidOpen,
    );
  }

  Future<void> simulateLidState({
    required bool lidOpen,
    required bool packagePresent,
  }) async {
    final order = _currentOrder;
    if (order == null) return;
    gateway.injectSimulatedTelemetry(
      lidOpen: lidOpen,
      packagePresent: packagePresent,
    );
    await _dispatchTamper(
      orderId: order.cleanOrderId,
      smartBoxId: order.smartBoxId,
      lidOpen: lidOpen,
      packagePresent: packagePresent,
    );
  }

  Future<void> _dispatchTelemetry({
    required String smartBoxId,
    required String orderId,
    required double temperature,
    required bool lidOpen,
  }) async {
    final sent = await _api.ingestTelemetry(
      smartBoxId: smartBoxId,
      orderId: orderId,
      temperature: temperature,
      lidOpen: lidOpen,
    );
    if (sent) {
      if (!_backendOnline) {
        _backendOnline = true;
        notifyListeners();
      }
      await flushOfflineQueue();
    } else {
      await offlineQueue.enqueue('telemetry', {
        'smartBoxId': smartBoxId,
        'orderId': orderId,
        'temperature': temperature,
        'lidOpen': lidOpen,
      });
      if (_backendOnline) {
        _backendOnline = false;
      }
      notifyListeners();
    }
  }

  Future<void> _dispatchTamper({
    required String orderId,
    required String smartBoxId,
    required bool lidOpen,
    required bool packagePresent,
  }) async {
    final sent = await _api.reportTamperEvent(
      orderId: orderId,
      smartBoxId: smartBoxId,
      lidOpen: lidOpen,
      packagePresent: packagePresent,
    );
    if (!sent) {
      await offlineQueue.enqueue('tamper', {
        'orderId': orderId,
        'smartBoxId': smartBoxId,
        'lidOpen': lidOpen,
        'packagePresent': packagePresent,
      });
      notifyListeners();
    }
  }

  Future<int> flushOfflineQueue() async {
    if (offlineQueue.pendingCount == 0) return 0;
    final flushed = await offlineQueue.flush((item) async {
      switch (item.kind) {
        case 'telemetry':
          return _api.ingestTelemetry(
            smartBoxId: (item.payload['smartBoxId'] ?? '').toString(),
            orderId: (item.payload['orderId'] ?? '').toString(),
            temperature: (item.payload['temperature'] as num?)?.toDouble() ?? 0.0,
            lidOpen: item.payload['lidOpen'] == true,
          );
        case 'tamper':
          return _api.reportTamperEvent(
            orderId: (item.payload['orderId'] ?? '').toString(),
            smartBoxId: (item.payload['smartBoxId'] ?? '').toString(),
            lidOpen: item.payload['lidOpen'] == true,
            packagePresent: item.payload['packagePresent'] != false,
          );
        case 'evidence':
          final r = await _api.submitEvidence(
            orderId: (item.payload['orderId'] ?? '').toString(),
            photoBase64OrUrl: (item.payload['photoBase64OrUrl'] ?? '').toString(),
          );
          return r.fromBackend;
        default:
          return true;
      }
    });
    if (flushed > 0) notifyListeners();
    return flushed;
  }

  void _startSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final order = _currentOrder;
      if (order == null) return;
      await _dispatchTelemetry(
        smartBoxId: order.smartBoxId,
        orderId: order.cleanOrderId,
        temperature: order.currentTemp,
        lidOpen: order.lidOpen,
      );
    });
  }

  void _stopSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _stopSyncLoop();
    _bleSub?.cancel();
    _gpsSub?.cancel();
    gateway.dispose();
    super.dispose();
  }
}
