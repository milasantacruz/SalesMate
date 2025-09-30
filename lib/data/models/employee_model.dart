import 'package:odoo_repository/odoo_repository.dart';
import 'package:equatable/equatable.dart';

/// Modelo para representar un empleado de Odoo (hr.employee)
class Employee extends Equatable implements OdooRecord {
  const Employee({
    required this.id,
    required this.name,
    this.workEmail,
    this.workPhone,
    this.jobTitle,
    this.departmentId,
    this.departmentName,
    this.managerId,
    this.managerName,
    this.active = true,
    this.employeeType,
  });

  @override
  final int id;
  final String name;
  final String? workEmail;
  final String? workPhone;
  final String? jobTitle;
  final int? departmentId;
  final String? departmentName;
  final int? managerId;
  final String? managerName;
  final bool active;
  final String? employeeType;

  /// Crea un Employee desde JSON
  factory Employee.fromJson(Map<String, dynamic> json) {
    // Helper robusto para parsear campos de relación (Many2one)
    int? parseMany2oneId(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value[0] as int?;
      }
      if (value is int) {
        return value;
      }
      return null; // Maneja `false`, `null` y listas vacías
    }

    String? parseMany2oneName(dynamic value) {
      if (value is List && value.length > 1) {
        return value[1] as String?;
      }
      return null;
    }

    return Employee(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : '',
      workEmail: json['work_email'] is String ? json['work_email'] : null,
      workPhone: json['work_phone'] is String ? json['work_phone'] : null,
      jobTitle: json['job_title'] is String ? json['job_title'] : null,
      departmentId: parseMany2oneId(json['department_id']),
      departmentName: parseMany2oneName(json['department_id']),
      managerId: parseMany2oneId(json['parent_id']),
      managerName: parseMany2oneName(json['parent_id']),
      active: json['active'] as bool? ?? true,
      employeeType:
          json['employee_type'] is String ? json['employee_type'] : null,
    );
  }

  /// Convierte el Employee a JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'work_email': workEmail,
      'work_phone': workPhone,
      'job_title': jobTitle,
      'department_id': departmentId,
      'parent_id': managerId,
      'active': active,
      'employee_type': employeeType,
    };
  }

  /// Propiedades para Equatable
  @override
  List<Object?> get props => [
        id,
        name,
        workEmail,
        workPhone,
        jobTitle,
        departmentId,
        departmentName,
        managerId,
        managerName,
        active,
        employeeType,
      ];

  /// Campos que se solicitan a Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'work_email',
        'work_phone',
        'job_title',
        'department_id',
        'parent_id',
        'active',
        'employee_type',
      ];

  /// Representación como string
  @override
  String toString() {
    return 'Employee{id: $id, name: $name, jobTitle: $jobTitle, department: $departmentName, active: $active}';
  }

  /// Convierte a valores para crear/actualizar en Odoo
  Map<String, dynamic> toVals() {
    final vals = <String, dynamic>{};

    vals['name'] = name;
    if (workEmail != null) vals['work_email'] = workEmail;
    if (workPhone != null) vals['work_phone'] = workPhone;
    if (jobTitle != null) vals['job_title'] = jobTitle;
    if (departmentId != null) vals['department_id'] = departmentId;
    if (managerId != null) vals['parent_id'] = managerId;
    vals['active'] = active;
    if (employeeType != null) vals['employee_type'] = employeeType;

    return vals;
  }
}


