import 'package:hive_flutter/hive_flutter.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Implementación personalizada de OdooKv usando Hive
class CustomOdooKv implements OdooKv {
  late Box _box;
  static const String _boxName = 'odoo_cache';

  @override
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  @override
  Future<void> close() async {
    await _box.close();
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    await _box.put(key, value);
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _box.get(key, defaultValue: defaultValue);
  }

  @override
  Future<void> delete(dynamic key) async {
    await _box.delete(key);
  }

  @override
  Iterable get keys => _box.keys;
}
