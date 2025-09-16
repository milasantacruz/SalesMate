import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/employee_model.dart';

/// Repository para manejar operaciones con Employees en Odoo
class EmployeeRepository {
  final OdooEnvironment env;
  List<Employee> latestRecords = [];

  final String modelName = 'hr.employee';
  List<String> get oFields => Employee.oFields;
  List<dynamic> get oDomain => [['active', '=', true]];

  EmployeeRepository(this.env);

  Future<void> fetchRecords() async {
    try {
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

      final records = response as List<dynamic>;
      latestRecords =
          records.map((json) => Employee.fromJson(json)).toList();
    } on OdooException catch (e) {
      // Handle Odoo specific errors, e.g. session expired
      print('OdooException in EmployeeRepository: $e');
      latestRecords = [];
    } catch (e) {
      print('Generic error in EmployeeRepository: $e');
      latestRecords = [];
    }
  }

  /// Obtiene la lista actual de empleados
  List<Employee> get currentEmployees => latestRecords;

  /// Obtiene todos los empleados activos
  Future<List<Employee>> getActiveEmployees() async {
    await fetchRecords();
    return latestRecords;
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

  /// Dispara la carga de records desde el servidor
  Future<void> loadRecords() async {
    print('👥 EMPLOYEE_REPO: Iniciando loadRecords()');
    print('👥 EMPLOYEE_REPO: Modelo: $modelName');

    try {
      print('⏳ EMPLOYEE_REPO: Llamando fetchRecords()...');
      await fetchRecords();
      print('✅ EMPLOYEE_REPO: fetchRecords() ejecutado');
      print('📊 EMPLOYEE_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ EMPLOYEE_REPO: Error en loadRecords(): $e');
      print('❌ EMPLOYEE_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Crea un nuevo empleado
  Future<Employee> createEmployee(Employee employee) async {
    throw Exception(
        'Creación de empleados requiere session_id válido del servidor');
  }

  /// Actualiza un empleado existente
  Future<Employee> updateEmployee(Employee employee) async {
    throw Exception(
        'Actualización de empleados requiere session_id válido del servidor');
  }

  /// Desactiva un empleado (soft delete)
  Future<void> deactivateEmployee(int id) async {
    throw Exception(
        'Desactivación de empleados requiere session_id válido del servidor');
  }

  /// Elimina permanentemente un empleado
  Future<void> deleteEmployee(int id) async {
    throw Exception(
        'Eliminación de empleados requiere session_id válido del servidor');
  }
}
