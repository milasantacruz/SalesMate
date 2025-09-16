import 'package:equatable/equatable.dart';
import '../../../data/models/employee_model.dart';

/// Estados base para el manejo de employees
abstract class EmployeeState extends Equatable {
  const EmployeeState();
  @override
  List<Object> get props => [];
}

/// Estado inicial
class EmployeeInitial extends EmployeeState {}

/// Estado de carga
class EmployeeLoading extends EmployeeState {}

/// Estado cuando se han cargado los employees exitosamente
class EmployeeLoaded extends EmployeeState {
  final List<Employee> employees;
  
  const EmployeeLoaded(this.employees);
  
  @override
  List<Object> get props => [employees];
}

/// Estado cuando no hay employees para mostrar
class EmployeeEmpty extends EmployeeState {
  final String message;
  
  const EmployeeEmpty({this.message = 'No se encontraron empleados'});
  
  @override
  List<Object> get props => [message];
}

/// Estado de error
class EmployeeError extends EmployeeState {
  final String message;
  final String? details;
  
  const EmployeeError(this.message, {this.details});
  
  @override
  List<Object> get props => [message, details ?? ''];
}

/// Estado durante operaciones específicas (crear, actualizar, eliminar)
class EmployeeOperationInProgress extends EmployeeState {
  final List<Employee> employees; // Mantener lista actual
  final String operation;
  
  const EmployeeOperationInProgress(this.employees, this.operation);
  
  @override
  List<Object> get props => [employees, operation];
}

/// Estado cuando se muestran resultados de búsqueda
class EmployeeSearchResult extends EmployeeState {
  final List<Employee> employees;
  final String searchTerm;
  final String searchType; // 'name', 'jobTitle', 'department'
  
  const EmployeeSearchResult(this.employees, this.searchTerm, this.searchType);
  
  @override
  List<Object> get props => [employees, searchTerm, searchType];
}

/// Estado cuando se filtran employees por departamento
class EmployeeFilteredByDepartment extends EmployeeState {
  final List<Employee> employees;
  final int departmentId;
  
  const EmployeeFilteredByDepartment(this.employees, this.departmentId);
  
  @override
  List<Object> get props => [employees, departmentId];
}
