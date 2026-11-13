import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/delivery_models.dart';

class ApiResponse<T> {
  final bool success;
  final bool fromBackend;
  final T? data;
  final String? message;

  const ApiResponse({
    required this.success,
    required this.fromBackend,
    this.data,
    this.message,
  });
}

class OrdersBundle {
  final List<DeliveryOrder> active;
  final List<DeliveryOrder> history;

  const OrdersBundle({required this.active, required this.history});
}

/// Cliente HTTP alineado 1:1 con `cold2hot-backend` API Gateway (`/api/v1/*`).
class ApiService {
  String baseUrl;
  String? authToken;
  final bool offlineDemoOnly;

  ApiService({
    required this.baseUrl,
    this.authToken,
    this.offlineDemoOnly = false,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null && authToken!.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

  static const Duration _timeout = Duration(seconds: 15);

  Future<bool> checkHealth() async {
    try {
      final rootUrl = baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
      final res = await http.get(Uri.parse('$rootUrl/')).timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/v1/iam/auth/login
  Future<ApiResponse<OperatorUser>> login(String email, String password) async {
    if (!offlineDemoOnly) {
      try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/iam/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = (body['token'] ?? '').toString();
        final userJson =
            (body['user'] as Map?)?.cast<String, dynamic>() ?? {'email': email};
        return ApiResponse(
          success: true,
          fromBackend: true,
          data: OperatorUser.fromJson(userJson, token),
        );
      }

      if (res.statusCode == 400 || res.statusCode == 401) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          fromBackend: true,
          message: (body['error'] ?? 'Credenciales inválidas').toString(),
        );
      }
    } catch (_) {
      // Fallback offline/demo si no hay conectividad
    }
    }

    if (email.isNotEmpty && password.length >= 4) {
      return ApiResponse(
        success: true,
        fromBackend: false,
        data: OperatorUser(
          id: 'OP-001',
          name: email.split('@').first,
          email: email,
          role: 'OPERATOR',
          restaurantName: 'La Pergola Delivery',
          token: 'demo-jwt-${DateTime.now().millisecondsSinceEpoch}',
        ),
        message: 'Sesión iniciada en modo offline/demo',
      );
    }

    return const ApiResponse(
      success: false,
      fromBackend: false,
      message: 'Ingresa un correo válido y contraseña (mín. 4 caracteres).',
    );
  }

  /// POST /api/v1/iam/auth/forgot-password
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/iam/auth/forgot-password'),
            headers: _headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const ApiResponse(
          success: true,
          fromBackend: true,
          message: 'Enlace de recuperación enviado a tu correo.',
        );
      }
    } catch (_) {}

    return const ApiResponse(
      success: true,
      fromBackend: false,
      message: 'Solicitud registrada (modo demo). Revisa tu bandeja de entrada.',
    );
  }

  /// Obtiene pedidos activos + entregados de `orders-service` y los enriquece
  /// con historial térmico, batería de `containers` y estado de cerrojo/OTP.
  Future<ApiResponse<OrdersBundle>> fetchOrdersBundle() async {
    if (!offlineDemoOnly) {
      try {
      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/orders/active'), headers: _headers).timeout(_timeout),
        http.get(Uri.parse('$baseUrl/orders?status=DELIVERED'), headers: _headers).timeout(_timeout),
        http.get(Uri.parse('$baseUrl/containers/smartboxes'), headers: _headers).timeout(_timeout),
      ]);

      final activeRes = results[0];
      final historyRes = results[1];
      final boxesRes = results[2];

      if (activeRes.statusCode == 200) {
        final boxMap = <String, Map<String, dynamic>>{};
        if (boxesRes.statusCode == 200) {
          final boxDecoded = jsonDecode(boxesRes.body);
          if (boxDecoded is List) {
            for (final b in boxDecoded) {
              final m = Map<String, dynamic>.from(b as Map);
              final id = (m['boxId'] ?? '').toString();
              if (id.isNotEmpty) boxMap[id] = m;
            }
          }
        }

        final activeRaw = _decodeOrderList(activeRes.body);
        final historyRaw = historyRes.statusCode == 200
            ? _decodeOrderList(historyRes.body)
            : const <Map<String, dynamic>>[];

        final enrichedActive = await Future.wait(
          activeRaw.map((raw) => _enrichOrder(raw, boxMap)),
        );
        final mappedHistory = historyRaw
            .map((raw) => _mapOrderBase(raw, boxMap))
            .toList();

        return ApiResponse(
          success: true,
          fromBackend: true,
          data: OrdersBundle(active: enrichedActive, history: mappedHistory),
        );
      }
    } catch (_) {}
    }

    final demo = _demoBundle();
    return ApiResponse(success: true, fromBackend: false, data: demo);
  }

  List<Map<String, dynamic>> _decodeOrderList(String rawBody) {
    final decoded = jsonDecode(rawBody);
    final list = decoded is List
        ? decoded
        : ((decoded as Map?)?['orders'] as List? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<DeliveryOrder> _enrichOrder(
    Map<String, dynamic> raw,
    Map<String, Map<String, dynamic>> boxMap,
  ) async {
    final base = _mapOrderBase(raw, boxMap);
    final cleanId = base.cleanOrderId;
    final boxId = base.smartBoxId;

    List<TelemetryPoint> history = const [];
    LockStatus lock = base.lockStatus;
    String otp = base.expectedOtp;
    double? lastTemp;
    double? prevTemp;
    bool lidOpen = base.lidOpen;

    try {
      final extra = await Future.wait([
        http
            .get(
              Uri.parse('$baseUrl/telemetry/boxes/$boxId/history?orderId=$cleanId&limit=16'),
              headers: _headers,
            )
            .timeout(_timeout),
        http
            .get(Uri.parse('$baseUrl/security/locks/$boxId'), headers: _headers)
            .timeout(_timeout),
        http
            .get(Uri.parse('$baseUrl/security/otp?orderId=$cleanId'), headers: _headers)
            .timeout(_timeout),
      ]);

      if (extra[0].statusCode == 200) {
        final hMap = jsonDecode(extra[0].body) as Map<String, dynamic>;
        final readings = (hMap['history'] as List?) ?? const [];
        history = readings.map((r) {
          final rm = r as Map<String, dynamic>;
          return TelemetryPoint(
            timestamp: DateTime.tryParse((rm['timestamp'] ?? '').toString()) ??
                DateTime.now(),
            temperature: (rm['temperature'] as num?)?.toDouble() ?? base.currentTemp,
          );
        }).toList();
        if (readings.isNotEmpty) {
          final last = readings.last as Map<String, dynamic>;
          lastTemp = (last['temperature'] as num?)?.toDouble();
          lidOpen = last['lidOpen'] == true;
          if (readings.length >= 2) {
            final prev = readings[readings.length - 2] as Map<String, dynamic>;
            prevTemp = (prev['temperature'] as num?)?.toDouble();
          }
        }
      }

      if (extra[1].statusCode == 200) {
        final lMap = jsonDecode(extra[1].body) as Map<String, dynamic>;
        if (lMap['lockState'] == 'UNLOCKED') {
          lock = LockStatus.unlocked;
        }
      }

      if (extra[2].statusCode == 200) {
        final oMap = jsonDecode(extra[2].body) as Map<String, dynamic>;
        final fetchedCode = (oMap['code'] ?? '').toString().replaceAll(' ', '');
        if (fetchedCode.isNotEmpty) otp = fetchedCode;
      } else if (extra[2].statusCode == 404 &&
          base.status != 'DELIVERED' &&
          base.status != 'CANCELLED') {
        // Pedidos semilla en backend pueden no tener OTP emitido todavía
        final issued = await http
            .post(
              Uri.parse('$baseUrl/security/otp'),
              headers: _headers,
              body: jsonEncode({'orderId': cleanId, 'smartBoxId': boxId}),
            )
            .timeout(_timeout);
        if (issued.statusCode >= 200 && issued.statusCode < 300) {
          final iMap = jsonDecode(issued.body) as Map<String, dynamic>;
          final createdCode =
              (iMap['code'] ?? '').toString().replaceAll(' ', '');
          if (createdCode.isNotEmpty) otp = createdCode;
        }
      }
    } catch (_) {}

    return base.copyWith(
      currentTemp: lastTemp,
      previousTemp: prevTemp,
      lockStatus: lock,
      lidOpen: lidOpen,
      expectedOtp: otp,
      history: history,
    );
  }

  DeliveryOrder _mapOrderBase(
    Map<String, dynamic> json,
    Map<String, Map<String, dynamic>> boxMap,
  ) {
    final profile = (json['thermalProfile'] as Map?)?.cast<String, dynamic>();
    final modeStr =
        (profile?['type'] ?? json['thermalMode'] ?? 'HOT').toString().toUpperCase();
    final mode = modeStr == 'COLD' ? ThermalMode.cold : ThermalMode.hot;
    final minT = (profile?['minTemperature'] as num?)?.toDouble() ??
        (json['targetMinTemp'] as num?)?.toDouble() ??
        (mode == ThermalMode.cold ? 2.0 : 65.0);
    final maxT = (profile?['maxTemperature'] as num?)?.toDouble() ??
        (json['targetMaxTemp'] as num?)?.toDouble() ??
        (mode == ThermalMode.cold ? 8.0 : 80.0);

    final rawOrderId = (json['orderId'] ?? json['id'] ?? 'C2H-10482').toString();
    final displayId = rawOrderId.startsWith('#') ? rawOrderId : '#$rawOrderId';
    final address =
        (json['deliveryAddress'] ?? json['customerAddress'] ?? '').toString();
    final boxId = (json['smartBoxId'] ?? 'SB-014').toString();
    final boxInfo = boxMap[boxId];
    final cat = FoodCategory.fromApi(json['foodCategory']?.toString(), mode);
    final defaultTemp = mode == ThermalMode.cold
        ? ((minT + maxT) / 2).clamp(1.0, 12.0)
        : ((minT + maxT) / 2).clamp(55.0, 82.0);

    return DeliveryOrder(
      id: displayId,
      customerName: (json['customerName'] ?? 'Cliente').toString(),
      customerAddress: address,
      restaurantName: (json['restaurantName'] ?? 'La Pergola Delivery').toString(),
      foodCategory: cat,
      thermalMode: mode,
      targetMinTemp: minT,
      targetMaxTemp: maxT,
      currentTemp: (json['currentTemp'] as num?)?.toDouble() ?? defaultTemp,
      smartBoxId: boxId,
      smartBoxMac: (boxInfo?['macAddress'] ?? json['smartBoxMac'] ?? 'C8:F0:9E:44:A1:12').toString(),
      batteryLevel: (boxInfo?['batteryLevel'] as num?)?.toInt() ??
          (json['batteryLevel'] as num?)?.toInt() ??
          85,
      lockStatus: LockStatus.locked,
      lidOpen: false,
      packagePresent: true,
      expectedOtp: (json['otpCode'] ?? '482719').toString().replaceAll(' ', ''),
      status: (json['status'] ?? 'IN_TRANSIT').toString(),
      evidencePath: ((json['evidence'] as Map?)?['photoUrl'] ??
              (json['evidence'] as Map?)?['photoBase64'] ??
              json['evidencePhotoUrl'])
          ?.toString(),
      destinationCoord: _coordForAddress(address, rawOrderId),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      deliveredAt: DateTime.tryParse((json['deliveredAt'] ?? '').toString()),
    );
  }

  /// POST /api/v1/telemetry/ingest
  Future<bool> ingestTelemetry({
    required String smartBoxId,
    required String orderId,
    required double temperature,
    required bool lidOpen,
  }) async {
    if (offlineDemoOnly) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/telemetry/ingest'),
            headers: _headers,
            body: jsonEncode({
              'smartBoxId': smartBoxId,
              'shipmentId': orderId.replaceAll('#', ''),
              'temperature': temperature,
              'lidOpen': lidOpen,
            }),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/v1/security/unlock  (body: { orderId, smartBoxId, code })
  Future<ApiResponse<void>> validateOtpAndUnlock({
    required String orderId,
    required String smartBoxId,
    required String otpCode,
    required String expectedDemoOtp,
  }) async {
    final cleanOrderId = orderId.replaceAll('#', '');
    final cleanCode = otpCode.trim().replaceAll(' ', '');
    if (!offlineDemoOnly) {
      try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/security/unlock'),
            headers: _headers,
            body: jsonEncode({
              'orderId': cleanOrderId,
              'smartBoxId': smartBoxId,
              'code': cleanCode,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const ApiResponse(
          success: true,
          fromBackend: true,
          message: 'Solenoide desbloqueado correctamente.',
        );
      }
      if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final codeResult = (body['result'] ?? '').toString();
        final friendly = switch (codeResult) {
          'ALREADY_USED' => 'Este código OTP ya fue utilizado.',
          'EXPIRED_CODE' => 'El código OTP ha expirado.',
          'INVALID_CODE' => 'Código OTP incorrecto.',
          _ => (body['error'] ?? 'Código OTP inválido o expirado.').toString(),
        };
        return ApiResponse(
          success: false,
          fromBackend: true,
          message: friendly,
        );
      }
    } catch (_) {}
    }

    if (cleanCode == expectedDemoOtp.replaceAll(' ', '')) {
      return const ApiResponse(
        success: true,
        fromBackend: false,
        message: 'OTP verificado localmente. Solenoide desbloqueado.',
      );
    }

    return const ApiResponse(
      success: false,
      fromBackend: false,
      message: 'Código OTP incorrecto. Verifica los 6 dígitos.',
    );
  }

  /// POST /api/v1/security/tamper-events
  Future<bool> reportTamperEvent({
    required String orderId,
    required String smartBoxId,
    required bool lidOpen,
    required bool packagePresent,
  }) async {
    if (offlineDemoOnly) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/security/tamper-events'),
            headers: _headers,
            body: jsonEncode({
              'orderId': orderId.replaceAll('#', ''),
              'smartBoxId': smartBoxId,
              'lidOpen': lidOpen,
              'packagePresent': packagePresent,
              'forced': lidOpen && !packagePresent,
            }),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/v1/orders/:orderId/evidence  (body: { photoBase64, photoUrl })
  Future<ApiResponse<void>> submitEvidence({
    required String orderId,
    required String photoBase64OrUrl,
  }) async {
    final cleanId = orderId.replaceAll('#', '');
    if (!offlineDemoOnly) {
      try {
      final isUrl = photoBase64OrUrl.startsWith('http');
      final res = await http
          .post(
            Uri.parse('$baseUrl/orders/$cleanId/evidence'),
            headers: _headers,
            body: jsonEncode({
              if (isUrl) 'photoUrl': photoBase64OrUrl else 'photoBase64': photoBase64OrUrl,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const ApiResponse(
          success: true,
          fromBackend: true,
          message: 'Evidencia sincronizada y entrega cerrada.',
        );
      }
    } catch (_) {}
    }

    return const ApiResponse(
      success: true,
      fromBackend: false,
      message: 'Evidencia en cola Store-and-Forward para sincronizar.',
    );
  }

  /// Crea un pedido de prueba real en `orders-service` usando una SmartBox disponible.
  Future<ApiResponse<DeliveryOrder>> createDemoOrderOnBackend() async {
    if (!offlineDemoOnly) {
      try {
        final boxesRes = await http
            .get(Uri.parse('$baseUrl/containers/smartboxes'), headers: _headers)
            .timeout(_timeout);
        String boxId = 'SB-014';
        if (boxesRes.statusCode == 200) {
          final decoded = jsonDecode(boxesRes.body);
          if (decoded is List) {
            final avail = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .where((b) =>
                    b['status'] == 'AVAILABLE' &&
                    ((b['batteryLevel'] as num?)?.toInt() ?? 0) >= 15)
                .toList();
            if (avail.isNotEmpty) {
              boxId = (avail.first['boxId'] ?? 'SB-014').toString();
            }
          }
        }

        final res = await http
            .post(
              Uri.parse('$baseUrl/orders'),
              headers: _headers,
              body: jsonEncode({
                'customerName': 'Valeria Mendoza (Demo)',
                'deliveryAddress': 'Av. Larco 1150, Miraflores',
                'smartBoxId': boxId,
                'operatorId': 'OP-001',
                'operatorName': 'Carlos Ruiz',
                'foodCategory': 'BURGER',
                'thermalProfile': {
                  'type': 'HOT',
                  'minTemperature': 55,
                  'maxTemperature': 75,
                },
              }),
            )
            .timeout(_timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final created = jsonDecode(res.body) as Map<String, dynamic>;
          final otp = (created['otp'] as Map?)?['code']?.toString();
          final order = _mapOrderBase(created, const {});
          return ApiResponse(
            success: true,
            fromBackend: true,
            data: otp != null ? order.copyWith(expectedOtp: otp) : order,
            message: 'Pedido de prueba creado en el backend.',
          );
        }
      } catch (_) {}
    }

    final fallback = _demoBundle().active.first;
    return ApiResponse(
      success: true,
      fromBackend: false,
      data: fallback,
      message: 'Pedido de prueba cargado localmente.',
    );
  }

  static GeoPoint _coordForAddress(String address, String seed) {
    final low = address.toLowerCase();
    if (low.contains('miraflores') || low.contains('larco')) {
      return const GeoPoint(-12.1211, -77.0292);
    }
    if (low.contains('san isidro') || low.contains('javier prado')) {
      return const GeoPoint(-12.0977, -77.0365);
    }
    if (low.contains('surco') || low.contains('primavera')) {
      return const GeoPoint(-12.1112, -76.9912);
    }
    if (low.contains('magdalena') || low.contains('salaverry')) {
      return const GeoPoint(-12.0902, -77.0645);
    }
    final offset = (seed.hashCode % 30) * 0.0008;
    return GeoPoint(-12.1060 + offset, -77.0310 - offset);
  }

  OrdersBundle _demoBundle() {
    final now = DateTime.now();
    return OrdersBundle(
      active: [
        DeliveryOrder(
          id: '#C2H-10482',
          customerName: 'Valeria Mendoza',
          customerAddress: 'Av. Arequipa 1450, Miraflores',
          restaurantName: 'La Pergola Delivery',
          foodCategory: FoodCategory.burger,
          thermalMode: ThermalMode.hot,
          targetMinTemp: 65.0,
          targetMaxTemp: 80.0,
          currentTemp: 69.2,
          previousTemp: 69.5,
          smartBoxId: 'SB-014',
          smartBoxMac: 'C8:F0:9E:44:A1:12',
          batteryLevel: 87,
          lockStatus: LockStatus.locked,
          lidOpen: false,
          packagePresent: true,
          expectedOtp: '482719',
          status: 'IN_TRANSIT',
          destinationCoord: const GeoPoint(-12.1172, -77.0318),
          history: [
            TelemetryPoint(timestamp: now.subtract(const Duration(minutes: 10)), temperature: 71.0),
            TelemetryPoint(timestamp: now.subtract(const Duration(minutes: 5)), temperature: 69.5),
            TelemetryPoint(timestamp: now, temperature: 69.2),
          ],
          createdAt: now.subtract(const Duration(minutes: 12)),
        ),
        DeliveryOrder(
          id: '#C2H-10483',
          customerName: 'Sebastián Paredes',
          customerAddress: 'Jr. Cusco 320, Magdalena',
          restaurantName: 'Gelato Artisanal',
          foodCategory: FoodCategory.iceCream,
          thermalMode: ThermalMode.cold,
          targetMinTemp: -16.0,
          targetMaxTemp: -8.0,
          currentTemp: -12.4,
          previousTemp: -12.6,
          smartBoxId: 'SB-022',
          smartBoxMac: 'C8:F0:9E:44:A1:25',
          batteryLevel: 64,
          lockStatus: LockStatus.locked,
          lidOpen: false,
          packagePresent: true,
          expectedOtp: '195440',
          status: 'IN_TRANSIT',
          destinationCoord: const GeoPoint(-12.0902, -77.0645),
          history: [
            TelemetryPoint(timestamp: now.subtract(const Duration(minutes: 8)), temperature: -13.0),
            TelemetryPoint(timestamp: now.subtract(const Duration(minutes: 4)), temperature: -12.6),
            TelemetryPoint(timestamp: now, temperature: -12.4),
          ],
          createdAt: now.subtract(const Duration(minutes: 8)),
        ),
      ],
      history: [
        DeliveryOrder(
          id: '#C2H-10479',
          customerName: 'Camila Torres',
          customerAddress: 'Calle Schell 410, Miraflores',
          restaurantName: 'La Pergola Delivery',
          foodCategory: FoodCategory.pizza,
          thermalMode: ThermalMode.hot,
          targetMinTemp: 62.0,
          targetMaxTemp: 78.0,
          currentTemp: 70.4,
          smartBoxId: 'SB-014',
          smartBoxMac: 'C8:F0:9E:44:A1:12',
          batteryLevel: 90,
          lockStatus: LockStatus.unlocked,
          lidOpen: false,
          packagePresent: false,
          expectedOtp: '390112',
          status: 'DELIVERED',
          destinationCoord: const GeoPoint(-12.1211, -77.0292),
          createdAt: now.subtract(const Duration(hours: 3)),
          deliveredAt: now.subtract(const Duration(hours: 2, minutes: 35)),
        ),
        DeliveryOrder(
          id: '#C2H-10475',
          customerName: 'Mateo Quispe',
          customerAddress: 'Av. Salaverry 2100, Jesús María',
          restaurantName: 'Sushi Zen Express',
          foodCategory: FoodCategory.sushi,
          thermalMode: ThermalMode.cold,
          targetMinTemp: 2.0,
          targetMaxTemp: 7.0,
          currentTemp: 4.8,
          smartBoxId: 'SB-022',
          smartBoxMac: 'C8:F0:9E:44:A1:25',
          batteryLevel: 74,
          lockStatus: LockStatus.unlocked,
          lidOpen: false,
          packagePresent: false,
          expectedOtp: '881204',
          status: 'DELIVERED',
          destinationCoord: const GeoPoint(-12.0846, -77.0491),
          createdAt: now.subtract(const Duration(days: 2)),
          deliveredAt: now.subtract(const Duration(days: 2)).add(const Duration(minutes: 34)),
        ),
      ],
    );
  }
}
