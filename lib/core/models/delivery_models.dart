import 'dart:math' as math;

enum ThermalMode { cold, hot }

enum ThermalStatus { optimal, warning, breach }

enum LockStatus { locked, unlocked }

enum TamperAlertLevel { none, lidOpen, unauthorizedAccess }

enum AppLanguage { es, en }

enum FoodCategory {
  burger,
  pizza,
  hotDrink,
  iceCream,
  coldDrink,
  sushi;

  String get apiValue {
    switch (this) {
      case FoodCategory.burger:
        return 'BURGER';
      case FoodCategory.pizza:
        return 'PIZZA';
      case FoodCategory.hotDrink:
        return 'HOT_DRINK';
      case FoodCategory.iceCream:
        return 'ICE_CREAM';
      case FoodCategory.coldDrink:
        return 'COLD_DRINK';
      case FoodCategory.sushi:
        return 'SUSHI';
    }
  }

  ThermalMode get defaultMode {
    switch (this) {
      case FoodCategory.burger:
      case FoodCategory.pizza:
      case FoodCategory.hotDrink:
        return ThermalMode.hot;
      case FoodCategory.iceCream:
      case FoodCategory.coldDrink:
      case FoodCategory.sushi:
        return ThermalMode.cold;
    }
  }

  static FoodCategory fromApi(String? raw, ThermalMode fallbackMode) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case 'BURGER':
        return FoodCategory.burger;
      case 'PIZZA':
        return FoodCategory.pizza;
      case 'HOT_DRINK':
        return FoodCategory.hotDrink;
      case 'ICE_CREAM':
        return FoodCategory.iceCream;
      case 'COLD_DRINK':
        return FoodCategory.coldDrink;
      case 'SUSHI':
        return FoodCategory.sushi;
      default:
        return fallbackMode == ThermalMode.cold
            ? FoodCategory.iceCream
            : FoodCategory.burger;
    }
  }
}

enum DeliveryStep {
  orderDetail,     // M04
  bleConnect,      // M05
  inTransit,       // M06 / M07
  otpUnlock,       // M08 / M09
  boxUnlocked,     // M10
  captureEvidence, // M11
  reviewEvidence,  // M12
  completed,       // M13
}

class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['lat'] as num?)?.toDouble() ?? -12.1191,
        (json['lng'] as num?)?.toDouble() ?? -77.0289,
      );
}

class TelemetryPoint {
  final DateTime timestamp;
  final double temperature;

  const TelemetryPoint({required this.timestamp, required this.temperature});
}

class TelemetryPacket {
  final String smartBoxId;
  final double temperature;
  final double? humidity;
  final int batteryLevel;
  final LockStatus lockStatus;
  final bool lidOpen;
  final bool packagePresent;
  final int rssi;
  final DateTime timestamp;
  final bool isSimulated;

  const TelemetryPacket({
    required this.smartBoxId,
    required this.temperature,
    this.humidity,
    required this.batteryLevel,
    required this.lockStatus,
    required this.lidOpen,
    required this.packagePresent,
    required this.rssi,
    required this.timestamp,
    this.isSimulated = false,
  });
}

class DevicePermissionsStatus {
  final bool locationServiceEnabled;
  final bool locationGranted;
  final bool locationForeverDenied;
  final bool bluetoothGranted;
  final bool cameraGranted;

  const DevicePermissionsStatus({
    this.locationServiceEnabled = false,
    this.locationGranted = false,
    this.locationForeverDenied = false,
    this.bluetoothGranted = false,
    this.cameraGranted = false,
  });

  bool get allRequiredGranted => locationServiceEnabled && locationGranted;

  bool get allHardwareReady =>
      locationServiceEnabled &&
      locationGranted &&
      bluetoothGranted &&
      cameraGranted;

  DevicePermissionsStatus copyWith({
    bool? locationServiceEnabled,
    bool? locationGranted,
    bool? locationForeverDenied,
    bool? bluetoothGranted,
    bool? cameraGranted,
  }) {
    return DevicePermissionsStatus(
      locationServiceEnabled:
          locationServiceEnabled ?? this.locationServiceEnabled,
      locationGranted: locationGranted ?? this.locationGranted,
      locationForeverDenied:
          locationForeverDenied ?? this.locationForeverDenied,
      bluetoothGranted: bluetoothGranted ?? this.bluetoothGranted,
      cameraGranted: cameraGranted ?? this.cameraGranted,
    );
  }
}

class OfflineSyncItem {
  final String id;
  final String kind; // telemetry | tamper | evidence
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const OfflineSyncItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) =>
      OfflineSyncItem(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? 'telemetry').toString(),
        payload: Map<String, dynamic>.from(
          (json['payload'] as Map?) ?? const {},
        ),
        createdAt:
            DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
                DateTime.now(),
      );
}

class OperatorUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String restaurantName;
  final String token;

  const OperatorUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.restaurantName,
    required this.token,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'OP';
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory OperatorUser.fromJson(Map<String, dynamic> json, String token) {
    return OperatorUser(
      id: (json['id'] ?? 'OP-001').toString(),
      name: (json['name'] ?? 'Operador').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'OPERATOR').toString(),
      restaurantName: (json['restaurantName'] ?? 'La Pergola Delivery').toString(),
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'restaurantName': restaurantName,
        'token': token,
      };
}

class DeliveryOrder {
  final String id; // display format e.g. #C2H-10482
  final String customerName;
  final String customerAddress;
  final String restaurantName;
  final FoodCategory foodCategory;
  final ThermalMode thermalMode;
  final double targetMinTemp;
  final double targetMaxTemp;
  final double currentTemp;
  final double? previousTemp;
  final String smartBoxId;
  final String smartBoxMac;
  final int batteryLevel;
  final LockStatus lockStatus;
  final bool lidOpen;
  final bool packagePresent;
  final String expectedOtp;
  final String status;
  final String? evidencePath;
  final GeoPoint destinationCoord;
  final List<TelemetryPoint> history;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  const DeliveryOrder({
    required this.id,
    required this.customerName,
    required this.customerAddress,
    required this.restaurantName,
    required this.foodCategory,
    required this.thermalMode,
    required this.targetMinTemp,
    required this.targetMaxTemp,
    required this.currentTemp,
    this.previousTemp,
    required this.smartBoxId,
    required this.smartBoxMac,
    required this.batteryLevel,
    required this.lockStatus,
    required this.lidOpen,
    required this.packagePresent,
    required this.expectedOtp,
    required this.status,
    this.evidencePath,
    required this.destinationCoord,
    this.history = const [],
    required this.createdAt,
    this.deliveredAt,
  });

  String get cleanOrderId => id.replaceAll('#', '');

  ThermalStatus get thermalStatus {
    if (currentTemp < targetMinTemp || currentTemp > targetMaxTemp) {
      return ThermalStatus.breach;
    }
    const margin = 1.5;
    if (currentTemp <= targetMinTemp + margin ||
        currentTemp >= targetMaxTemp - margin) {
      return ThermalStatus.warning;
    }
    return ThermalStatus.optimal;
  }

  TamperAlertLevel get tamperLevel {
    if (!lidOpen) return TamperAlertLevel.none;
    if (lockStatus == LockStatus.unlocked) return TamperAlertLevel.none;
    if (packagePresent) return TamperAlertLevel.lidOpen;
    return TamperAlertLevel.unauthorizedAccess;
  }

  DeliveryOrder copyWith({
    double? currentTemp,
    double? previousTemp,
    int? batteryLevel,
    LockStatus? lockStatus,
    bool? lidOpen,
    bool? packagePresent,
    String? expectedOtp,
    String? status,
    String? evidencePath,
    List<TelemetryPoint>? history,
    DateTime? deliveredAt,
  }) {
    return DeliveryOrder(
      id: id,
      customerName: customerName,
      customerAddress: customerAddress,
      restaurantName: restaurantName,
      foodCategory: foodCategory,
      thermalMode: thermalMode,
      targetMinTemp: targetMinTemp,
      targetMaxTemp: targetMaxTemp,
      currentTemp: currentTemp ?? this.currentTemp,
      previousTemp: previousTemp ?? this.previousTemp,
      smartBoxId: smartBoxId,
      smartBoxMac: smartBoxMac,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lockStatus: lockStatus ?? this.lockStatus,
      lidOpen: lidOpen ?? this.lidOpen,
      packagePresent: packagePresent ?? this.packagePresent,
      expectedOtp: expectedOtp ?? this.expectedOtp,
      status: status ?? this.status,
      evidencePath: evidencePath ?? this.evidencePath,
      destinationCoord: destinationCoord,
      history: history ?? this.history,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}

class BleDeviceInfo {
  final String id;
  final String name;
  final String macAddress;
  final int rssi;
  final bool isSimulated;

  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.isSimulated = false,
  });

  double get estimatedDistanceMeters {
    const txPower = -59;
    final ratio = (txPower - rssi) / 20.0;
    final raw = math.pow(10, ratio).toDouble();
    return raw.clamp(0.2, 25.0);
  }

  String get signalQuality {
    if (rssi >= -60) return 'Excelente';
    if (rssi >= -75) return 'Buena';
    return 'Débil';
  }
}
