import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/network/network_connectivity.dart';
import '../../core/errors/session_expired_handler.dart';
import '../../core/session/session_ready.dart';

/// Clase base abstracta para repositorios que soportan modo offline.
///
/// Hereda de [OdooRepository] para reutilizar el sistema de caché y el stream,
/// pero sobrescribe [fetchRecords] para implementar una estrategia offline-first.
abstract class OfflineOdooRepository<T extends OdooRecord>
    extends OdooRepository<T> {
  late final OdooEnvironment env;
  late final NetworkConnectivity netConn;
  late final OdooKv cache;
  List<T> latestRecords = [];
  
  OfflineOdooRepository(OdooEnvironment environment, this.netConn, this.cache)
      : env = environment,
        super(environment);

  /// Forces subclasses to provide a way to convert from JSON to the record type [T].
  /// This method is called by [fetchRecords] after getting data from the server.
  T fromJson(Map<String, dynamic> json);

  /// Lista de campos a solicitar en la llamada `search_read`.
  /// Cada sub-repositorio debe implementar esto.
  List<String> get oFields;

  /// Método abstracto que las subclases deben implementar para definir
  /// cómo se buscan los registros en Odoo.
  /// Esto nos permite usar `search_read` con dominios personalizados en lugar
  /// del `web_search_read` por defecto de la librería.
  Future<List<dynamic>> searchRead();

  @override
  Future<void> fetchRecords() async {
    try {
      // Esperar si hay una re-autenticación silenciosa en curso
      await SessionReadyCoordinator.waitIfReauthenticationInProgress();

      if (await netConn.checkNetConn() == netConnState.online) {
        // ONLINE: Obtener datos frescos del servidor
        final recordsJson = await searchRead();
        final records =
            recordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();

        // Guardar en caché para uso offline
        await cache.put('${T.toString()}_records', records.map((r) => r.toJson()).toList());
        
        // Actualizar la lista local
        latestRecords = records;
      } else {
        // OFFLINE: Cargar datos desde la caché local
        final cachedData = cache.get('${T.toString()}_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final cachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          latestRecords = cachedRecords;
        } else {
          latestRecords = <T>[];
        }
      }
    } on OdooException catch (e) {
      // Verificar si es sesión expirada y manejarla
      final wasHandled = await SessionExpiredHandler.handleIfSessionExpired(e);
      if (wasHandled) {
        print('🔄 Sesión expirada - relanzando error para que BLoC maneje');
        // Relanzar el error para que el BLoC emita AuthUnauthenticated
        rethrow;
      }
      // Si es otro tipo de error de Odoo, relanzarlo
      rethrow;
    } catch (_) {
      // Para otros errores (ej. de red), intentamos cargar desde caché como fallback
      try {
        final cachedData = cache.get('${T.toString()}_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final cachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          latestRecords = cachedRecords;
        } else {
          latestRecords = <T>[];
        }
      } catch (cacheErr) {
        // Si la caché también falla, emitimos una lista vacía
        latestRecords = <T>[];
      }
    }
  }
}
