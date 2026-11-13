import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/delivery_models.dart';

/// Gateway BLE GATT para el microcontrolador ESP32 de la SmartBox Cold2Hot.
/// Maneja el descubrimiento de servicio/características GATT, flujo continuo de
/// telemetría (temperatura, tapa, batería, paquete) y comandos al solenoide,
/// con respaldo automático en modo simulador cuando no hay hardware físico.
class BleGattGateway {
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String telemetryCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String commandCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  bool simulateBle = kIsWeb;

  final StreamController<TelemetryPacket> _packetController =
      StreamController<TelemetryPacket>.broadcast();

  Stream<TelemetryPacket> get telemetryStream => _packetController.stream;

  BluetoothDevice? _nativeDevice;
  BluetoothCharacteristic? _commandChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _simTimer;

  BleDeviceInfo? _activeDevice;
  double _simTemp = 68.4;
  int _simBattery = 87;
  LockStatus _simLock = LockStatus.locked;
  bool _simLidOpen = false;
  bool _simPackagePresent = true;
  ThermalMode _simMode = ThermalMode.hot;
  int _simTick = 0;

  bool get isConnected => _activeDevice != null;

  Future<List<BleDeviceInfo>> scanForSmartBox({
    required String targetBoxId,
    required String targetMac,
  }) async {
    if (simulateBle || kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 700));
      return [
        BleDeviceInfo(
          id: targetBoxId,
          name: 'Cold2Hot-$targetBoxId',
          macAddress: targetMac,
          rssi: -52,
          isSimulated: true,
        ),
        const BleDeviceInfo(
          id: 'SB-022',
          name: 'Cold2Hot-SB-022',
          macAddress: 'C8:F0:9E:44:A1:25',
          rssi: -74,
          isSimulated: true,
        ),
      ];
    }

    final found = <BleDeviceInfo>[];
    StreamSubscription<List<ScanResult>>? sub;
    try {
      final state = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
      );
      if (state != BluetoothAdapterState.on) {
        throw Exception('Bluetooth desactivado');
      }

      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          if (name.isEmpty) continue;
          final mac = r.device.remoteId.str;
          if (!found.any((d) => d.macAddress == mac)) {
            found.add(
              BleDeviceInfo(
                id: name,
                name: name,
                macAddress: mac,
                rssi: r.rssi,
                isSimulated: false,
              ),
            );
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
    } catch (_) {
      return [
        BleDeviceInfo(
          id: targetBoxId,
          name: 'Cold2Hot-$targetBoxId (Simulador)',
          macAddress: targetMac,
          rssi: -54,
          isSimulated: true,
        ),
      ];
    } finally {
      await sub?.cancel();
    }

    return found.isNotEmpty
        ? found
        : [
            BleDeviceInfo(
              id: targetBoxId,
              name: 'Cold2Hot-$targetBoxId (Simulador)',
              macAddress: targetMac,
              rssi: -54,
              isSimulated: true,
            ),
          ];
  }

  Future<bool> connectToDevice(
    BleDeviceInfo device, {
    required double initialTemp,
    required int initialBattery,
    required LockStatus initialLock,
    required ThermalMode mode,
  }) async {
    await disconnect();
    _activeDevice = device;
    _simTemp = initialTemp;
    _simBattery = initialBattery;
    _simLock = initialLock;
    _simLidOpen = false;
    _simPackagePresent = true;
    _simMode = mode;
    _simTick = 0;

    if (device.isSimulated || kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 550));
      _startSimulatedStream(device.id, device.rssi);
      return true;
    }

    try {
      final bleDevice = BluetoothDevice.fromId(device.macAddress);
      await bleDevice.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 6),
      );
      _nativeDevice = bleDevice;

      final services = await bleDevice.discoverServices();
      for (final svc in services) {
        if (svc.uuid.str.toLowerCase() == serviceUuid) {
          for (final chr in svc.characteristics) {
            final uid = chr.uuid.str.toLowerCase();
            if (uid == telemetryCharUuid) {
              await chr.setNotifyValue(true);
              _notifySub = chr.onValueReceived.listen((bytes) {
                final packet = _parseGattPayload(bytes, device);
                if (packet != null && !_packetController.isClosed) {
                  _packetController.add(packet);
                }
              });
            } else if (uid == commandCharUuid) {
              _commandChar = chr;
            }
          }
        }
      }

      _connSub = bleDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _activeDevice != null) {
          _startSimulatedStream(device.id, -85);
        }
      });
      return true;
    } catch (_) {
      _activeDevice = null;
      return false;
    }
  }

  Future<void> writeSolenoidUnlock(String otpCode) async {
    _simLock = LockStatus.unlocked;
    if (_commandChar != null) {
      try {
        await _commandChar!.write(
          utf8.encode(jsonEncode({'cmd': 'UNLOCK', 'code': otpCode})),
          withoutResponse: false,
        );
      } catch (_) {}
    }
    _emitCurrentSimPacket();
  }

  void injectSimulatedTelemetry({
    double? temperature,
    bool? lidOpen,
    bool? packagePresent,
    LockStatus? lockStatus,
    int? batteryLevel,
  }) {
    if (temperature != null) _simTemp = temperature;
    if (lidOpen != null) _simLidOpen = lidOpen;
    if (packagePresent != null) _simPackagePresent = packagePresent;
    if (lockStatus != null) _simLock = lockStatus;
    if (batteryLevel != null) _simBattery = batteryLevel;
    _emitCurrentSimPacket();
  }

  void _startSimulatedStream(String boxId, int rssi) {
    _simTimer?.cancel();
    _emitCurrentSimPacket(rssiOverride: rssi);
    _simTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _simTick++;
      // Suave oscilación térmica realista para reflejar lectura viva del DS18B20
      final drift = (_simTick % 2 == 0) ? 0.15 : -0.15;
      _simTemp = double.parse((_simTemp + drift).toStringAsFixed(1));
      if (_simTick % 6 == 0 && _simBattery > 10) {
        _simBattery--;
      }
      _emitCurrentSimPacket(rssiOverride: rssi);
    });
  }

  void _emitCurrentSimPacket({int? rssiOverride}) {
    final dev = _activeDevice;
    if (dev == null || _packetController.isClosed) return;
    _packetController.add(
      TelemetryPacket(
        smartBoxId: dev.id,
        temperature: _simTemp,
        humidity: _simMode == ThermalMode.hot ? 48.0 : 62.0,
        batteryLevel: _simBattery,
        lockStatus: _simLock,
        lidOpen: _simLidOpen,
        packagePresent: _simPackagePresent,
        rssi: rssiOverride ?? dev.rssi,
        timestamp: DateTime.now(),
        isSimulated: dev.isSimulated,
      ),
    );
  }

  TelemetryPacket? _parseGattPayload(List<int> bytes, BleDeviceInfo device) {
    try {
      final raw = utf8.decode(bytes).trim();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TelemetryPacket(
        smartBoxId: device.id,
        temperature: (map['temp'] as num?)?.toDouble() ?? _simTemp,
        humidity: (map['hum'] as num?)?.toDouble(),
        batteryLevel: (map['bat'] as num?)?.toInt() ?? _simBattery,
        lockStatus: map['locked'] == false ? LockStatus.unlocked : LockStatus.locked,
        lidOpen: map['lidOpen'] == true,
        packagePresent: map['pkg'] != false,
        rssi: device.rssi,
        timestamp: DateTime.now(),
        isSimulated: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    _simTimer?.cancel();
    _simTimer = null;
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    _commandChar = null;
    if (_nativeDevice != null) {
      try {
        await _nativeDevice!.disconnect();
      } catch (_) {}
      _nativeDevice = null;
    }
    _activeDevice = null;
  }

  void dispose() {
    disconnect();
    _packetController.close();
  }
}
