import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/models/employee_model.dart';
import 'employee_event.dart';
import 'employee_state.dart';

/// BLoC para manejar la lógica de employees
class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  final EmployeeRepository _employeeRepository;

  EmployeeBloc(this._employeeRepository) : super(EmployeeInitial()) {
    on<LoadEmployees>(_onLoadEmployees);
    on<RefreshEmployees>(_onRefreshEmployees);
    on<CreateEmployee>(_onCreateEmployee);
    on<UpdateEmployee>(_onUpdateEmployee);
    on<DeleteEmployee>(_onDeleteEmployee);
    on<SearchEmployeesByName>(_onSearchEmployeesByName);
    on<SearchEmployeesByJobTitle>(_onSearchEmployeesByJobTitle);
    on<FilterEmployeesByDepartment>(_onFilterEmployeesByDepartment);
    on<EmployeesUpdated>(_onEmployeesUpdated);
  }

  /// Maneja la carga inicial de employees
  Future<void> _onLoadEmployees(
      LoadEmployees event, Emitter<EmployeeState> emit) async {
    print('👥 EMPLOYEE_BLOC: Iniciando carga de employees...');
    emit(EmployeeLoading());

    try {
      print('⏳ EMPLOYEE_BLOC: Llamando await _employeeRepository.loadRecords()...');
      // 1. Esperar a que la llamada de red termine
      await _employeeRepository.loadRecords();
      print('✅ EMPLOYEE_BLOC: loadRecords() completado.');
      
      // 2. Obtener los datos (ahora sí están disponibles)
      final employees = _employeeRepository.latestRecords;
      print('📊 EMPLOYEE_BLOC: ${employees.length} employees obtenidos.');

      // 3. Emitir el estado correcto con los datos
      if (employees.isEmpty) {
        emit(const EmployeeEmpty(message: 'No se encontraron empleados'));
      } else {
        emit(EmployeeLoaded(employees));
      }
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error cargando employees: $e');
      emit(EmployeeError('Error cargando empleados: $e'));
    }
  }

  /// Maneja la actualización/refresh de employees
  Future<void> _onRefreshEmployees(RefreshEmployees event, Emitter<EmployeeState> emit) async {
    print('🔄 EMPLOYEE_BLOC: Refrescando employees...');
    
    try {
      // Recargar datos del repositorio
      _employeeRepository.loadRecords();
      
      // Mostrar loading solo si no tenemos datos previos
      if (state is EmployeeInitial || state is EmployeeEmpty || state is EmployeeError) {
        emit(EmployeeLoading());
      }
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error refrescando employees: $e');
      emit(EmployeeError('Error refrescando empleados: $e'));
    }
  }

  /// Maneja la creación de un nuevo employee
  Future<void> _onCreateEmployee(CreateEmployee event, Emitter<EmployeeState> emit) async {
    print('➕ EMPLOYEE_BLOC: Creando employee: ${event.employee.name}');
    
    // Mostrar estado de operación en progreso
    final currentEmployees = _getCurrentEmployees();
    emit(EmployeeOperationInProgress(currentEmployees, 'Creando empleado...'));
    
    try {
      await _employeeRepository.createEmployee(event.employee);
      print('✅ EMPLOYEE_BLOC: Employee creado exitosamente');
      
      // Recargar datos
      _employeeRepository.loadRecords();
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error creando employee: $e');
      emit(EmployeeError('Error creando empleado: $e'));
    }
  }

  /// Maneja la actualización de un employee
  Future<void> _onUpdateEmployee(UpdateEmployee event, Emitter<EmployeeState> emit) async {
    print('✏️ EMPLOYEE_BLOC: Actualizando employee: ${event.employee.name}');
    
    final currentEmployees = _getCurrentEmployees();
    emit(EmployeeOperationInProgress(currentEmployees, 'Actualizando empleado...'));
    
    try {
      await _employeeRepository.updateEmployee(event.employee);
      print('✅ EMPLOYEE_BLOC: Employee actualizado exitosamente');
      
      // Recargar datos
      _employeeRepository.loadRecords();
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error actualizando employee: $e');
      emit(EmployeeError('Error actualizando empleado: $e'));
    }
  }

  /// Maneja la eliminación de un employee
  Future<void> _onDeleteEmployee(DeleteEmployee event, Emitter<EmployeeState> emit) async {
    print('🗑️ EMPLOYEE_BLOC: Eliminando employee ID: ${event.employeeId}');
    
    final currentEmployees = _getCurrentEmployees();
    emit(EmployeeOperationInProgress(currentEmployees, 'Eliminando empleado...'));
    
    try {
      await _employeeRepository.deleteEmployee(event.employeeId);
      print('✅ EMPLOYEE_BLOC: Employee eliminado exitosamente');
      
      // Recargar datos
      _employeeRepository.loadRecords();
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error eliminando employee: $e');
      emit(EmployeeError('Error eliminando empleado: $e'));
    }
  }

  /// Maneja la búsqueda de employees por nombre
  Future<void> _onSearchEmployeesByName(SearchEmployeesByName event, Emitter<EmployeeState> emit) async {
    print('🔍 EMPLOYEE_BLOC: Buscando employees por nombre: ${event.name}');
    
    if (event.name.trim().isEmpty) {
      add(RefreshEmployees());
      return;
    }
    
    emit(EmployeeLoading());
    
    try {
      final results = await _employeeRepository.searchByName(event.name);
      print('🔍 EMPLOYEE_BLOC: Encontrados ${results.length} employees');
      
      emit(EmployeeSearchResult(results, event.name, 'name'));
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error buscando employees por nombre: $e');
      emit(EmployeeError('Error buscando empleados: $e'));
    }
  }

  /// Maneja la búsqueda de employees por puesto
  Future<void> _onSearchEmployeesByJobTitle(SearchEmployeesByJobTitle event, Emitter<EmployeeState> emit) async {
    print('💼 EMPLOYEE_BLOC: Buscando employees por puesto: ${event.jobTitle}');
    
    if (event.jobTitle.trim().isEmpty) {
      add(RefreshEmployees());
      return;
    }
    
    emit(EmployeeLoading());
    
    try {
      final results = await _employeeRepository.searchByJobTitle(event.jobTitle);
      print('💼 EMPLOYEE_BLOC: Encontrados ${results.length} employees');
      
      emit(EmployeeSearchResult(results, event.jobTitle, 'jobTitle'));
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error buscando employees por puesto: $e');
      emit(EmployeeError('Error buscando empleados por puesto: $e'));
    }
  }

  /// Maneja el filtro de employees por departamento
  Future<void> _onFilterEmployeesByDepartment(FilterEmployeesByDepartment event, Emitter<EmployeeState> emit) async {
    print('🏢 EMPLOYEE_BLOC: Filtrando employees por departamento ID: ${event.departmentId}');
    
    emit(EmployeeLoading());
    
    try {
      final results = await _employeeRepository.getEmployeesByDepartment(event.departmentId);
      print('🏢 EMPLOYEE_BLOC: Encontrados ${results.length} employees');
      
      emit(EmployeeFilteredByDepartment(results, event.departmentId));
    } catch (e) {
      print('❌ EMPLOYEE_BLOC: Error filtrando employees por departamento: $e');
      emit(EmployeeError('Error filtrando empleados por departamento: $e'));
    }
  }

  /// Maneja las actualizaciones del stream de employees
  Future<void> _onEmployeesUpdated(EmployeesUpdated event, Emitter<EmployeeState> emit) async {
    print('🔄 EMPLOYEE_BLOC: Employees actualizados: ${event.employees.length} items');
    
    if (event.employees.isEmpty) {
      emit(const EmployeeEmpty());
    } else {
      emit(EmployeeLoaded(event.employees));
    }
  }

  /// Obtiene la lista actual de employees del estado
  List<Employee> _getCurrentEmployees() {
    final currentState = state;
    if (currentState is EmployeeLoaded) {
      return currentState.employees;
    } else if (currentState is EmployeeSearchResult) {
      return currentState.employees;
    } else if (currentState is EmployeeFilteredByDepartment) {
      return currentState.employees;
    } else if (currentState is EmployeeOperationInProgress) {
      return currentState.employees;
    }
    return [];
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
