import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/delivery_models.dart';

/// Cola Store-and-Forward en almacenamiento local para paquetes IoT y evidencias
/// cuando el repartidor atraviesa zonas sin cobertura celular (túneles, sótanos).
class OfflineSyncQueue {
  static const _storageKey = 'c2h_offline_sync_queue_v1';
  static const int _maxItems = 200;

  final bool persistToDisk;
  final List<OfflineSyncItem> _items = [];

  OfflineSyncQueue({this.persistToDisk = true});

  List<OfflineSyncItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map((e) => OfflineSyncItem.fromJson(Map<String, dynamic>.from(e as Map))),
        );
    } catch (_) {
      _items.clear();
    }
  }

  Future<void> enqueue(String kind, Map<String, dynamic> payload) async {
    final item = OfflineSyncItem(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_items.length}',
      kind: kind,
      payload: payload,
      createdAt: DateTime.now(),
    );
    _items.add(item);
    if (_items.length > _maxItems) {
      _items.removeAt(0);
    }
    await _persist();
  }

  /// Intenta enviar todos los paquetes en orden FIFO y retorna cuántos se sincronizaron.
  Future<int> flush(Future<bool> Function(OfflineSyncItem item) sender) async {
    if (_items.isEmpty) return 0;
    int synced = 0;
    final remaining = <OfflineSyncItem>[];
    bool stopOnNetworkFail = false;

    for (final item in _items) {
      if (stopOnNetworkFail) {
        remaining.add(item);
        continue;
      }
      final ok = await sender(item);
      if (ok) {
        synced++;
      } else {
        stopOnNetworkFail = true;
        remaining.add(item);
      }
    }

    if (synced > 0) {
      _items
        ..clear()
        ..addAll(remaining);
      await _persist();
    }
    return synced;
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  Future<void> _persist() async {
    if (!persistToDisk) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }
}
