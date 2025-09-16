import 'package:equatable/equatable.dart';
import '../../../data/models/employee_model.dart';

/// Eventos base para el manejo de employees
abstract class EmployeeEvent extends Equatable {
  const EmployeeEvent();
  @override
  List<Object> get props => [];
}

/// Evento para cargar employees inicialmente
class LoadEmployees extends EmployeeEvent {}

/// Evento para refrescar employees
class RefreshEmployees extends EmployeeEvent {}

/// Evento para crear un nuevo employee
class CreateEmployee extends EmployeeEvent {
  final Employee employee;
  
  const CreateEmployee(this.employee);
  
  @override
  List<Object> get props => [employee];
}

/// Evento para actualizar un employee
class UpdateEmployee extends EmployeeEvent {
  final Employee employee;
  
  const UpdateEmployee(this.employee);
  
  @override
  List<Object> get props => [employee];
}

/// Evento para eliminar un employee
class DeleteEmployee extends EmployeeEvent {
  final int employeeId;
  
  const DeleteEmployee(this.employeeId);
  
  @override
  List<Object> get props => [employeeId];
}

/// Evento para buscar employees por nombre
class SearchEmployeesByName extends EmployeeEvent {
  final String name;
  
  const SearchEmployeesByName(this.name);
  
  @override
  List<Object> get props => [name];
}

/// Evento para buscar employees por puesto
class SearchEmployeesByJobTitle extends EmployeeEvent {
  final String jobTitle;
  
  const SearchEmployeesByJobTitle(this.jobTitle);
  
  @override
  List<Object> get props => [jobTitle];
}

/// Evento para filtrar employees por departamento
class FilterEmployeesByDepartment extends EmployeeEvent {
  final int departmentId;
  
  const FilterEmployeesByDepartment(this.departmentId);
  
  @override
  List<Object> get props => [departmentId];
}

/// Evento cuando se actualizan los employees
class EmployeesUpdated extends EmployeeEvent {
  final List<Employee> employees;
  
  const EmployeesUpdated(this.employees);
  
  @override
  List<Object> get props => [employees];
}
