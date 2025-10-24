import 'package:odoo_repository/odoo_repository.dart';
import '../models/partner_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';

/// Repository para manejar operaciones con Partners en Odoo con soporte offline
class PartnerRepository extends OfflineOdooRepository<Partner> {
  final String modelName = 'res.partner';
  late final OdooCallQueueRepository _callQueue;
  List<dynamic> get oDomain => [
    ['active', '=', true],
    ['type', '=', 'contact'],
  ];

  PartnerRepository(
    OdooEnvironment env,
    NetworkConnectivity netConn,
    OdooKv cache, {
    super.tenantCache,
  }) : super(env, netConn, cache) {
    // Inicializar _callQueue desde dependency injection
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => Partner.oFields;

  @override
  Partner fromJson(Map<String, dynamic> json) => Partner.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    print('📋 PARTNER_REPO: Buscando partners con domain: $oDomain');
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': oDomain,
        'fields': oFields,
        'limit': 80,
        'offset': 0,
        'order': 'name'
      },
    });
    
    final records = response as List<dynamic>;
    print('📋 PARTNER_REPO: ${records.length} contactos activos encontrados');
    
    return records;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIncrementalRecords(String since) async {
    print('🔄 PARTNER_REPO: Fetch incremental desde $since');
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['active', '=', true],
          ['type', '=', 'contact'],
          ['write_date', '>', since], // 👈 Filtro de fecha incremental
        ],
        'fields': oFields,
        'limit': 1000, // Alto límite (usualmente pocos cambios)
        'offset': 0,
        'order': 'write_date asc',
      },
    });
    
    final records = response as List<dynamic>;
    print('🔄 PARTNER_REPO: ${records.length} registros incrementales obtenidos');
    
    return records.cast<Map<String, dynamic>>();
  }


  /// Obtiene la lista actual de partners
  List<Partner> get currentPartners => latestRecords;

  /// Obtiene todos los partners activos
  Future<List<Partner>> getActivePartners() async {
    await fetchRecords();
    return latestRecords;
  }

  /// Obtiene solo los clientes
  Future<List<Partner>> getCustomers() async {
    await fetchRecords();
    return latestRecords.where((partner) => partner.customerRank > 0).toList();
  }

  /// Obtiene solo los proveedores
  Future<List<Partner>> getSuppliers() async {
    await fetchRecords();
    return latestRecords.where((partner) => partner.supplierRank > 0).toList();
  }

  /// Obtiene partners que son tanto clientes como proveedores
  Future<List<Partner>> getCustomerSuppliers() async {
    await fetchRecords();
    return latestRecords
        .where(
            (partner) => partner.customerRank > 0 && partner.supplierRank > 0)
        .toList();
  }

  /// Obtiene solo las empresas
  Future<List<Partner>> getCompanies() async {
    await fetchRecords();
    return latestRecords.where((partner) => partner.isCompany).toList();
  }

  /// Busca partners por nombre
  Future<List<Partner>> searchByName(String name) async {
    await fetchRecords();
    return latestRecords
        .where(
            (partner) => partner.name.toLowerCase().contains(name.toLowerCase()))
        .toList();
  }

  /// Busca partners por email
  Future<List<Partner>> searchByEmail(String email) async {
    await fetchRecords();
    return latestRecords
        .where((partner) =>
            partner.email?.toLowerCase().contains(email.toLowerCase()) ?? false)
        .toList();
  }

  /// Obtiene un partner por ID
  Future<Partner?> getPartnerById(int id) async {
    await fetchRecords();
    try {
      return currentPartners.firstWhere((partner) => partner.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene direcciones de despacho de un partner (commercial_partner_id)
  Future<List<Partner>> getDeliveryAddresses(int commercialPartnerId) async {
    try {
      print('📋 PARTNER_REPO: Obteniendo direcciones de despacho para partner $commercialPartnerId');
      
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
      
      print('📋 PARTNER_REPO: ${addresses.length} direcciones de despacho encontradas');
      return addresses;
    } catch (e) {
      print('❌ PARTNER_REPO: Error obteniendo direcciones de despacho: $e');
      return [];
    }
  }

  /// Crea una nueva dirección de despacho
  Future<Partner?> createDeliveryAddress(Map<String, dynamic> addressData) async {
    try {
      print('📋 PARTNER_REPO: Creando nueva dirección de despacho...');
      print('📋 PARTNER_REPO: Datos: $addressData');
      
      // Asegurar que el type es delivery
      final finalData = {
        ...addressData,
        'type': 'delivery',
        'active': true,
      };
      
      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'create',
        'args': [finalData],
        'kwargs': {},
      });
      
      final newId = response as int;
      print('✅ PARTNER_REPO: Dirección creada con ID: $newId');
      
      // Leer la dirección recién creada
      final readResponse = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[newId]],
        'kwargs': {
          'fields': oFields,
        },
      });
      
      if (readResponse is List && readResponse.isNotEmpty) {
        final newAddress = Partner.fromJson(readResponse.first);
        print('✅ PARTNER_REPO: Dirección leída: ${newAddress.name}');
        return newAddress;
      }
      
      return null;
    } catch (e) {
      print('❌ PARTNER_REPO: Error creando dirección: $e');
      rethrow;
    }
  }

  /// Dispara la carga de records desde el servidor (con soporte offline)
  Future<void> loadRecords() async {
    print('📋 PARTNER_REPO: Iniciando loadRecords() con soporte offline');
    print('📋 PARTNER_REPO: Modelo: $modelName');

    try {
      print('⏳ PARTNER_REPO: Llamando fetchRecords()...');
      await fetchRecords(); // Usa el método de la clase base con lógica offline
      print('✅ PARTNER_REPO: fetchRecords() ejecutado');
      print('📊 PARTNER_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ PARTNER_REPO: Error en loadRecords(): $e');
      print('❌ PARTNER_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Crea un nuevo partner (offline/online según conectividad)
  Future<String> createPartner(Partner partner) async {
    return await _callQueue.createRecord(modelName, partner.toJson());
  }

  /// Actualiza un partner existente (offline/online según conectividad)
  Future<void> updatePartner(Partner partner) async {
    await _callQueue.updateRecord(modelName, partner.id, partner.toJson());
  }

  /// Desactiva un partner (soft delete)
  Future<void> deactivatePartner(int id) async {
    throw Exception(
        'Desactivación de partners requiere session_id válido del servidor');
  }

  /// Elimina permanentemente un partner (offline/online según conectividad)
  Future<void> deletePartner(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }
}

