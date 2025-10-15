import 'package:odoo_repository/odoo_repository.dart';
import '../models/employee_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';

/// Repository para manejar operaciones con Employees en Odoo con soporte offline
class EmployeeRepository extends OfflineOdooRepository<Employee> {
  final String modelName = 'hr.employee';
  late final OdooCallQueueRepository _callQueue;
  List<dynamic> get oDomain => [['active', '=', true]];

  EmployeeRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache) {
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => Employee.oFields;

  @override
  Employee fromJson(Map<String, dynamic> json) => Employee.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': oDomain,
        'fields': oFields,
      },
    });
    return response as List<dynamic>;
  }


  /// Obtiene la lista actual de empleados
  List<Employee> get currentEmployees => latestRecords;

  /// Obtiene todos los empleados activos
  Future<List<Employee>> getActiveEmployees() async {
    await fetchRecords();
    return latestRecords;
  }

  /// Busca empleado(s) por PIN
  Future<List<Employee>> findByPin(String pin) async {
    try {
      final results = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['pin', '=', pin]
          ],
          'fields': oFields,
          'limit': 5,
        },
      });
      final list = (results as List).map((e) => fromJson(e)).toList();
      return list;
    } catch (e) {
      print('❌ EMPLOYEE_REPO: Error findByPin: $e');
      return [];
    }
  }

  /// Valida el PIN de empleado y retorna el empleado si es único
  Future<Employee?> validatePin(String pin) async {
    final matches = await findByPin(pin);
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;
    // Si hay múltiples, el caller debe resolver desambiguación
    return null;
  }

  /// Obtiene empleados por departamento
  Future<List<Employee>> getEmployeesByDepartment(int departmentId) async {
    await fetchRecords();
    return latestRecords
        .where((employee) => employee.departmentId == departmentId)
        .toList();
  }

  /// Obtiene solo los managers (empleados que tienen subordinados)
  Future<List<Employee>> getManagers() async {
    fetchRecords();
    final managerIds = currentEmployees
        .where((emp) => emp.managerId != null)
        .map((emp) => emp.managerId!)
        .toSet();

    return currentEmployees
        .where((employee) =>
            managerIds.contains(employee.id) && employee.active)
        .toList();
  }

  /// Busca empleados por nombre
  Future<List<Employee>> searchByName(String name) async {
    await fetchRecords();
    return latestRecords
        .where((employee) =>
            employee.name.toLowerCase().contains(name.toLowerCase()))
        .toList();
  }

  /// Busca empleados por puesto de trabajo
  Future<List<Employee>> searchByJobTitle(String jobTitle) async {
    await fetchRecords();
    return latestRecords
        .where((employee) =>
            employee.jobTitle?.toLowerCase().contains(jobTitle.toLowerCase()) ==
            true)
        .toList();
  }

  /// Busca empleados por email
  Future<List<Employee>> searchByEmail(String email) async {
    await fetchRecords();
    return latestRecords
        .where((employee) =>
            employee.workEmail?.toLowerCase().contains(email.toLowerCase()) ==
            true)
        .toList();
  }

  /// Obtiene un empleado por ID
  Future<Employee?> getEmployeeById(int id) async {
    await fetchRecords();
    try {
      return currentEmployees.firstWhere((employee) => employee.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Dispara la carga de records desde el servidor (con soporte offline)
  Future<void> loadRecords() async {
    print('👥 EMPLOYEE_REPO: Iniciando loadRecords() con soporte offline');
    print('👥 EMPLOYEE_REPO: Modelo: $modelName');

    try {
      print('⏳ EMPLOYEE_REPO: Llamando fetchRecords()...');
      await fetchRecords(); // Usa el método de la clase base con lógica offline
      print('✅ EMPLOYEE_REPO: fetchRecords() ejecutado');
      print('📊 EMPLOYEE_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ EMPLOYEE_REPO: Error en loadRecords(): $e');
      print('❌ EMPLOYEE_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Crea un nuevo empleado (offline/online según conectividad)
  Future<String> createEmployee(Employee employee) async {
    return await _callQueue.createRecord(modelName, employee.toJson());
  }

  /// Actualiza un empleado existente (offline/online según conectividad)
  Future<void> updateEmployee(Employee employee) async {
    await _callQueue.updateRecord(modelName, employee.id, employee.toJson());
  }

  /// Desactiva un empleado (soft delete)
  Future<void> deactivateEmployee(int id) async {
    throw Exception(
        'Desactivación de empleados requiere session_id válido del servidor');
  }

  /// Elimina permanentemente un empleado (offline/online según conectividad)
  Future<void> deleteEmployee(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }
}


