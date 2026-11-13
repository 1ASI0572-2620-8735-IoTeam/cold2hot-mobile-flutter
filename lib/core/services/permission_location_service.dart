import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/delivery_models.dart';

/// Servicio real de permisos hardware (GPS, Bluetooth, Cámara) y ubicación en ruta.
/// Encapsula llamadas nativas de `geolocator` y `permission_handler` de forma segura
/// tanto en Android/iOS como en entornos Web o de pruebas sin canales nativos.
class PermissionLocationService {
  bool get _supportsRuntimePermissions {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<DevicePermissionsStatus> checkStatus() async {
    bool gpsEnabled = true;
    bool locGranted = false;
    bool locForeverDenied = false;
    bool bleGranted = true;
    bool camGranted = true;

    try {
      gpsEnabled = await Geolocator.isLocationServiceEnabled();
      final locPerm = await Geolocator.checkPermission();
      locGranted = locPerm == LocationPermission.always ||
          locPerm == LocationPermission.whileInUse;
      locForeverDenied = locPerm == LocationPermission.deniedForever;
    } catch (_) {
      // En test/desktop donde Geolocator no tiene binding nativo
      gpsEnabled = true;
      locGranted = kIsWeb;
    }

    if (_supportsRuntimePermissions) {
      try {
        final bleScan = await Permission.bluetoothScan.status;
        final bleConnect = await Permission.bluetoothConnect.status;
        final cam = await Permission.camera.status;
        bleGranted = bleScan.isGranted && bleConnect.isGranted;
        camGranted = cam.isGranted;
      } catch (_) {}
    }

    return DevicePermissionsStatus(
      locationServiceEnabled: gpsEnabled,
      locationGranted: locGranted,
      locationForeverDenied: locForeverDenied,
      bluetoothGranted: bleGranted,
      cameraGranted: camGranted,
    );
  }

  Future<DevicePermissionsStatus> requestAll() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}

    if (_supportsRuntimePermissions) {
      try {
        await [
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.camera,
        ].request();
      } catch (_) {}
    }

    return checkStatus();
  }

  Future<bool> openDeviceLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppPermissionsSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<GeoPoint?> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Stream<GeoPoint> watchLocation() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).map((pos) => GeoPoint(pos.latitude, pos.longitude));
    } catch (_) {
      return const Stream.empty();
    }
  }
}
