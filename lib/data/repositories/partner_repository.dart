import 'package:odoo_repository/odoo_repository.dart';
import '../models/partner_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';

/// Repository para manejar operaciones con Partners en Odoo con soporte offline
class PartnerRepository extends OfflineOdooRepository<Partner> {
  final String modelName = 'res.partner';
  List<dynamic> get oDomain => [
    ['active', '=', true],
    ['type', '=', 'contact'],
  ];

  PartnerRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache);

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

  /// Crea un nuevo partner
  Future<Partner> createPartner(Partner partner) async {
    throw Exception(
        'Creación de partners requiere session_id válido del servidor');
  }

  /// Actualiza un partner existente
  Future<Partner> updatePartner(Partner partner) async {
    throw Exception(
        'Actualización de partners requiere session_id válido del servidor');
  }

  /// Desactiva un partner (soft delete)
  Future<void> deactivatePartner(int id) async {
    throw Exception(
        'Desactivación de partners requiere session_id válido del servidor');
  }

  /// Elimina permanentemente un partner
  Future<void> deletePartner(int id) async {
    throw Exception(
        'Eliminación de partners requiere session_id válido del servidor');
  }
}