import 'package:odoo_repository/odoo_repository.dart';
import '../models/partner_model.dart';

/// Repository para manejar operaciones con Partners en Odoo
class PartnerRepository extends OdooRepository<Partner> {
  @override
  String get modelName => 'res.partner';

  PartnerRepository(OdooEnvironment environment) : super(environment);

  @override
  Partner createRecordFromJson(Map<String, dynamic> json) {
    return Partner.fromJson(json);
  }

  /// Obtiene la lista actual de partners
  List<Partner> get currentPartners => latestRecords;

  /// Obtiene todos los partners activos
  Future<List<Partner>> getActivePartners() async {
    // Usar fetchRecords() que es el método estándar de OdooRepository
    // Esto funcionará correctamente cuando el servidor tenga session_id válido
    fetchRecords(); // Dispara la carga de datos
    return currentPartners.where((partner) => partner.id > 0).toList();
  }

  /// Obtiene solo los clientes
  Future<List<Partner>> getCustomers() async {
    fetchRecords();
    return currentPartners.where((partner) => partner.customerRank > 0).toList();
  }

  /// Obtiene solo los proveedores
  Future<List<Partner>> getSuppliers() async {
    fetchRecords();
    return currentPartners.where((partner) => partner.supplierRank > 0).toList();
  }

  /// Obtiene partners que son tanto clientes como proveedores
  Future<List<Partner>> getCustomerSuppliers() async {
    fetchRecords();
    return currentPartners.where((partner) => 
      partner.customerRank > 0 && partner.supplierRank > 0).toList();
  }

  /// Obtiene solo las empresas
  Future<List<Partner>> getCompanies() async {
    fetchRecords();
    return currentPartners.where((partner) => partner.isCompany).toList();
  }

  /// Busca partners por nombre
  Future<List<Partner>> searchByName(String name) async {
    fetchRecords();
    return currentPartners.where((partner) => 
      partner.name.toLowerCase().contains(name.toLowerCase())).toList();
  }

  /// Busca partners por email
  Future<List<Partner>> searchByEmail(String email) async {
    fetchRecords();
    return currentPartners.where((partner) => 
      partner.email?.toLowerCase().contains(email.toLowerCase()) ?? false).toList();
  }

  /// Obtiene un partner por ID
  Future<Partner?> getPartnerById(int id) async {
    fetchRecords();
    try {
      return currentPartners.firstWhere((partner) => partner.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Dispara la carga de records desde el servidor
  void loadRecords() {
    fetchRecords();
  }

  /// Crea un nuevo partner
  Future<Partner> createPartner(Partner partner) async {
    // Usar el método estándar de OdooRepository cuando el session_id esté disponible
    // Por ahora lanza excepción explicativa
    throw Exception('Creación de partners requiere session_id válido del servidor');
  }

  /// Actualiza un partner existente
  Future<Partner> updatePartner(Partner partner) async {
    // Usar el método estándar de OdooRepository cuando el session_id esté disponible
    // Por ahora lanza excepción explicativa
    throw Exception('Actualización de partners requiere session_id válido del servidor');
  }

  /// Desactiva un partner (soft delete)
  Future<void> deactivatePartner(int id) async {
    // Usar el método estándar de OdooRepository cuando el session_id esté disponible
    // Por ahora lanza excepción explicativa
    throw Exception('Desactivación de partners requiere session_id válido del servidor');
  }

  /// Elimina permanentemente un partner
  Future<void> deletePartner(int id) async {
    // Usar el método estándar de OdooRepository cuando el session_id esté disponible
    // Por ahora lanza excepción explicativa
    throw Exception('Eliminación de partners requiere session_id válido del servidor');
  }
}
