import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/network/network_connectivity.dart';
import '../../core/errors/session_expired_handler.dart';
import '../../core/session/session_ready.dart';
import '../../core/tenant/tenant_aware_cache.dart';

/// Clase base abstracta para repositorios que soportan modo offline.
///
/// Hereda de [OdooRepository] para reutilizar el sistema de caché y el stream,
/// pero sobrescribe [fetchRecords] para implementar una estrategia offline-first.
abstract class OfflineOdooRepository<T extends OdooRecord>
    extends OdooRepository<T> {
  late final OdooEnvironment env;
  late final NetworkConnectivity netConn;
  late final OdooKv cache;
  final TenantAwareCache? tenantCache;
  List<T> latestRecords = [];
  
  OfflineOdooRepository(
    OdooEnvironment environment,
    this.netConn,
    this.cache, {
    this.tenantCache,
  }) : env = environment,
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
        print('🌐 OFFLINE_REPO: Modo ONLINE - obteniendo datos del servidor');
        
        try {
          final recordsJsonList = await searchRead();
          print('📡 OFFLINE_REPO: ${recordsJsonList.length} registros recibidos del servidor');
          final records =
              recordsJsonList.map((item) => fromJson(item as Map<String, dynamic>)).toList();
          print('✅ OFFLINE_REPO: ${records.length} registros convertidos a objetos');

          // Guardar en caché para uso offline
          final cacheKey = '${T.toString()}_records';
          final recordsJson = records.map((r) => r.toJson()).toList();
          
          print('💾 OFFLINE_REPO: Guardando en cache key "$cacheKey"');
          if (tenantCache != null) {
            await tenantCache!.put(cacheKey, recordsJson);
            print('✅ OFFLINE_REPO: Cache guardado usando tenantCache');
          } else {
            await cache.put(cacheKey, recordsJson);
            print('✅ OFFLINE_REPO: Cache guardado usando cache');
          }
          
          // Actualizar la lista local
          latestRecords = records;
          print('✅ OFFLINE_REPO: latestRecords asignado con ${latestRecords.length} registros');
        } catch (e, stackTrace) {
          // Si falla la solicitud HTTP, usar cache
          print('⚠️ OFFLINE_REPO: Error al obtener datos del servidor: $e');
          print('⚠️ OFFLINE_REPO: Cambiando a modo OFFLINE y cargando desde cache...');
          print('⚠️ OFFLINE_REPO: Stack: $stackTrace');
          
          // Forzar carga desde cache
          final cacheKey = '${T.toString()}_records';
          print('🔑 OFFLINE_REPO: Buscando key: "$cacheKey" en cache');
          print('🔍 OFFLINE_REPO: Usando tenantCache: ${tenantCache != null}');
          
          final cachedData = tenantCache != null
              ? tenantCache!.get<List>(cacheKey)
              : cache.get(cacheKey, defaultValue: <Map<String, dynamic>>[]);
              
          if (cachedData != null) {
            print('💾 OFFLINE_REPO: Datos encontrados en cache: true');
            print('📊 OFFLINE_REPO: Tipo de datos: ${cachedData.runtimeType}');
            if (cachedData is List) {
              print('📊 OFFLINE_REPO: Lista tiene ${cachedData.length} elementos');
            }
          }
          
          if (cachedData is List) {
            print('🔄 OFFLINE_REPO: Convirtiendo ${cachedData.length} elementos...');
            
            // Mostrar primeros 3 elementos para debugging
            if (cachedData.isNotEmpty) {
              print('🔍 OFFLINE_REPO: Primeros 3 elementos:');
              for (var i = 0; i < (cachedData.length > 3 ? 3 : cachedData.length); i++) {
                print('   [$i] Tipo: ${cachedData[i].runtimeType}');
                if (cachedData[i] is Map) {
                  print('   [$i] Es Map ✅');
                  try {
                    final typedMap = Map<String, dynamic>.from(cachedData[i]);
                    final test = fromJson(typedMap);
                    print('   [$i] fromJson() OK: ${test.runtimeType}');
                  } catch (e) {
                    print('   [$i] fromJson() FALLA: $e');
                  }
                } else {
                  print('   [$i] NO es Map: ${cachedData[i].runtimeType}');
                }
              }
            }
            
            final cachedRecords = cachedData.map((json) {
              try {
                if (json is Map) {
                  // Convertir _Map<dynamic, dynamic> a Map<String, dynamic>
                  final typedMap = Map<String, dynamic>.from(json);
                  return fromJson(typedMap);
                } else {
                  print('⚠️ OFFLINE_REPO: Elemento NO es Map: ${json.runtimeType}');
                  return null;
                }
              } catch (e) {
                print('⚠️ OFFLINE_REPO: Error en fromJson(): $e');
                return null;
              }
            }).whereType<T>().toList();
            
            print('✅ OFFLINE_REPO: ${cachedRecords.length} registros convertidos exitosamente');
            latestRecords = cachedRecords;
            print('✅ OFFLINE_REPO: ${cachedRecords.length} registros cargados desde cache');
          } else {
            latestRecords = <T>[];
            print('❌ OFFLINE_REPO: No hay datos en cache - latestRecords = 0');
          }
        }
      } else {
        // OFFLINE: Cargar datos desde la caché local
        print('📴 OFFLINE_REPO: Modo offline detectado - cargando desde cache');
        final cacheKey = '${T.toString()}_records';
        print('🔑 OFFLINE_REPO: Buscando key: "$cacheKey"');
        print('🔍 OFFLINE_REPO: Usando tenantCache: ${tenantCache != null}');
        
        final cachedData = tenantCache != null
            ? tenantCache!.get<List>(cacheKey)
            : cache.get(cacheKey, defaultValue: <Map<String, dynamic>>[]);
            
        print('💾 OFFLINE_REPO: Datos encontrados en cache: ${cachedData != null}');
        if (cachedData != null) {
          print('📊 OFFLINE_REPO: Tipo de datos: ${cachedData.runtimeType}');
          print('📊 OFFLINE_REPO: Es List: ${cachedData is List}');
          if (cachedData is List) {
            print('📊 OFFLINE_REPO: Lista tiene ${cachedData.length} elementos');
            if (cachedData.isNotEmpty) {
              print('📊 OFFLINE_REPO: Primer elemento: ${cachedData.first}');
              print('📊 OFFLINE_REPO: Tipo del primer elemento: ${cachedData.first.runtimeType}');
            } else {
              print('⚠️ OFFLINE_REPO: Lista existe pero está VACÍA');
            }
          }
        }
            
        if (cachedData is List) {
          print('🔄 OFFLINE_REPO: Convirtiendo ${cachedData.length} elementos...');
          
          // Mostrar solo los primeros 3 elementos para debugging
          if (cachedData.isNotEmpty) {
            print('🔍 OFFLINE_REPO: Primeros 3 elementos:');
            for (var i = 0; i < (cachedData.length > 3 ? 3 : cachedData.length); i++) {
              print('   [$i] Tipo: ${cachedData[i].runtimeType}');
              if (cachedData[i] is Map) {
                print('   [$i] Es Map ✅');
              } else {
                print('   [$i] NO es Map: ${cachedData[i].runtimeType}');
              }
            }
          }
          
          final cachedRecords = cachedData.map((json) {
            try {
              if (json is Map) {
                return fromJson(json as Map<String, dynamic>);
              } else {
                return null;
              }
            } catch (e) {
              return null;
            }
          }).whereType<T>().toList();
          
          print('✅ OFFLINE_REPO: ${cachedRecords.length} registros convertidos exitosamente');
          latestRecords = cachedRecords;
          print('✅ OFFLINE_REPO: ${cachedRecords.length} registros cargados desde cache');
        } else {
          print('⚠️ OFFLINE_REPO: cachedData NO es List, es: ${cachedData.runtimeType}');
          latestRecords = <T>[];
          print('❌ OFFLINE_REPO: Cache vacío o tipo incorrecto - latestRecords = 0');
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
        final cacheKey = '${T.toString()}_records';
        final cachedData = tenantCache != null
            ? tenantCache!.get<List>(cacheKey)
            : cache.get(cacheKey, defaultValue: <Map<String, dynamic>>[]);
            
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




