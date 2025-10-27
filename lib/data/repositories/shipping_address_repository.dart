import 'package:odoo_repository/odoo_repository.dart';
import '../models/partner_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';

/// Repository para manejar direcciones de despacho (shipping addresses)
/// 
/// Las shipping addresses son partners con type='delivery' en Odoo
class ShippingAddressRepository extends OfflineOdooRepository<Partner> {
  @override
  String get modelName => 'res.partner';

  @override
  List<String> get oFields => [
    'id', 'name', 'email', 'phone', 'is_company', 'customer_rank', 'supplier_rank', 
    'active', 'type', 'parent_id', 'commercial_partner_id', 'street', 'street2', 
    'city', 'city_id', 'state_id', 'country_id', 'zip'
  ];

  ShippingAddressRepository(
    OdooEnvironment env,
    NetworkConnectivity networkConnectivity,
    OdooKv kv, {
    super.tenantCache,
  }) : super(env, networkConnectivity, kv);

  @override
  Partner fromJson(Map<String, dynamic> json) => Partner.fromJson(json);

  /// Obtiene todas las direcciones de despacho activas
  Future<List<Partner>> getAllShippingAddresses() async {
    try {
      print('📍 SHIPPING_ADDRESS_REPO: Obteniendo todas las direcciones de despacho');
      
      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['active', '=', true],
            ['type', '=', 'delivery']
          ],
          'fields': oFields,
          'order': 'name'
        }
      });
      
      final records = response as List<dynamic>;
      final addresses = records.map((record) => Partner.fromJson(record)).toList();
      
      print('📍 SHIPPING_ADDRESS_REPO: ${addresses.length} direcciones de despacho encontradas');
      return addresses;
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error obteniendo direcciones: $e');
      rethrow;
    }
  }

  /// Obtiene direcciones de despacho de un partner específico
  Future<List<Partner>> getShippingAddressesForPartner(int commercialPartnerId) async {
    try {
      print('📍 SHIPPING_ADDRESS_REPO: Obteniendo direcciones para partner $commercialPartnerId');
      
      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['active', '=', true],
            ['type', '=', 'delivery'],
            ['commercial_partner_id', '=', commercialPartnerId]
          ],
          'fields': oFields,
          'order': 'name'
        }
      });
      
      final records = response as List<dynamic>;
      final addresses = records.map((record) => Partner.fromJson(record)).toList();
      
      print('📍 SHIPPING_ADDRESS_REPO: ${addresses.length} direcciones encontradas para partner $commercialPartnerId');
      return addresses;
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error obteniendo direcciones para partner: $e');
      rethrow;
    }
  }

  /// Crea una nueva dirección de despacho
  Future<Partner?> createShippingAddress(Map<String, dynamic> addressData) async {
    try {
      print('📍 SHIPPING_ADDRESS_REPO: Creando nueva dirección de despacho');
      
      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'create',
        'args': [addressData],
        'kwargs': {}
      });
      
      final addressId = response as int;
      print('📍 SHIPPING_ADDRESS_REPO: Dirección creada con ID: $addressId');
      
      // Obtener la dirección creada usando el método base
      final readResponse = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[addressId]],
        'kwargs': {'fields': oFields}
      });
      
      final records = readResponse as List<dynamic>;
      if (records.isNotEmpty) {
        return fromJson(records.first);
      }
      return null;
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error creando dirección: $e');
      rethrow;
    }
  }

  /// Actualiza una dirección de despacho existente
  Future<bool> updateShippingAddress(int addressId, Map<String, dynamic> updateData) async {
    try {
      print('📍 SHIPPING_ADDRESS_REPO: Actualizando dirección $addressId');
      
      await env.orpc.callKw({
        'model': modelName,
        'method': 'write',
        'args': [[addressId], updateData],
        'kwargs': {}
      });
      
      print('📍 SHIPPING_ADDRESS_REPO: Dirección $addressId actualizada exitosamente');
      return true;
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error actualizando dirección: $e');
      return false;
    }
  }

  /// Elimina una dirección de despacho (marca como inactiva)
  Future<bool> deleteShippingAddress(int addressId) async {
    try {
      print('📍 SHIPPING_ADDRESS_REPO: Eliminando dirección $addressId');
      
      await env.orpc.callKw({
        'model': modelName,
        'method': 'write',
        'args': [[addressId], {'active': false}],
        'kwargs': {}
      });
      
      print('📍 SHIPPING_ADDRESS_REPO: Dirección $addressId eliminada exitosamente');
      return true;
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error eliminando dirección: $e');
      return false;
    }
  }

  /// Implementación de fetchIncrementalRecords para sincronización incremental
  Future<List<Map<String, dynamic>>> fetchIncrementalRecords(String since) async {
    print('🔄 SHIPPING_ADDRESS_REPO: Fetch incremental desde $since');
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['active', '=', true],
          ['type', '=', 'delivery'],
          ['write_date', '>', since]
        ],
        'fields': oFields,
        'limit': 1000,
        'offset': 0,
        'order': 'write_date asc'
      }
    });
    
    final records = response as List<dynamic>;
    print('🔄 SHIPPING_ADDRESS_REPO: ${records.length} direcciones modificadas desde $since');
    
    return records.cast<Map<String, dynamic>>();
  }

  /// Obtiene direcciones de despacho desde caché offline
  List<Partner> getCachedShippingAddresses() {
    try {
      print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: Iniciando getCachedShippingAddresses()');
      print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: tenantCache != null: ${tenantCache != null}');
      
      // ✅ v2.0: Usar tenantCache si está disponible
      dynamic cachedData;
      
      if (tenantCache != null) {
        print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: Buscando en tenantCache');
        cachedData = tenantCache!.get('ShippingAddress_records');
        print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: cachedData != null: ${cachedData != null}');
        if (cachedData != null) {
          print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: cachedData tipo: ${cachedData.runtimeType}');
          print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: cachedData is List: ${cachedData is List}');
          if (cachedData is List) {
            print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: Lista tiene ${cachedData.length} elementos');
          }
        }
      } else {
        print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: Usando cache normal');
        cachedData = cache.get('ShippingAddress_records', defaultValue: <Map<String, dynamic>>[]);
      }
      
      if (cachedData is List) {
        print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: Convirtiendo ${cachedData.length} elementos...');
        // ✅ FIX: Usar Map.from() en lugar de cast directo para evitar errores con _Map<dynamic, dynamic>
        final cachedAddresses = cachedData.map((json) => fromJson(Map<String, dynamic>.from(json))).toList();
        print('📍 SHIPPING_ADDRESS_REPO: ${cachedAddresses.length} direcciones cargadas desde caché');
        return cachedAddresses;
      } else {
        print('🔍 DIAGNÓSTICO SHIPPING_ADDRESS: cachedData NO es List, es: ${cachedData.runtimeType}');
      }
      return [];
    } catch (e) {
      print('❌ SHIPPING_ADDRESS_REPO: Error cargando desde caché: $e');
      print('❌ SHIPPING_ADDRESS_REPO: Error tipo: ${e.runtimeType}');
      return [];
    }
  }

  /// Obtiene direcciones de despacho para un partner desde caché
  List<Partner> getCachedShippingAddressesForPartner(int commercialPartnerId) {
    final allAddresses = getCachedShippingAddresses();
    
    //print('🔍 SHIPPING_ADDRESS_REPO: Filtrando direcciones para partner $commercialPartnerId');
   // print('🔍 SHIPPING_ADDRESS_REPO: Total direcciones en caché: ${allAddresses.length}');
    
    // Log de cada dirección para debugging
    for (int i = 0; i < allAddresses.length; i++) {
      final addr = allAddresses[i];
      //print('🔍 SHIPPING_ADDRESS_REPO: Dirección $i: ID=${addr.id}, Name=${addr.name}, CommercialPartnerId=${addr.commercialPartnerId}');
    }
    
    final filteredAddresses = allAddresses.where((address) => address.commercialPartnerId == commercialPartnerId).toList();
    
    //print('🔍 SHIPPING_ADDRESS_REPO: Direcciones filtradas para partner $commercialPartnerId: ${filteredAddresses.length}');
    
    return filteredAddresses;
  }
}
