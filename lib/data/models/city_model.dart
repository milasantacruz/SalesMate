import 'package:odoo_repository/odoo_repository.dart';
import 'package:equatable/equatable.dart';

/// Modelo para representar una ciudad de Odoo (res.city)
class City extends Equatable implements OdooRecord {
  const City({
    required this.id,
    required this.name,
    this.zipcode,
    this.countryId,
    this.countryName,
    this.stateId,
    this.stateName,
  });

  @override
  final int id;
  final String name;
  final String? zipcode;
  final int? countryId;
  final String? countryName;
  final int? stateId;
  final String? stateName;

  /// Crea un City desde JSON
  factory City.fromJson(Map<String, dynamic> json) {
    // Helper para parsear campos Many2one
    int? parseMany2oneId(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value[0] as int?;
      }
      if (value is int) {
        return value;
      }
      return null;
    }

    String? parseMany2oneName(dynamic value) {
      if (value is List && value.length > 1) {
        return value[1] as String?;
      }
      return null;
    }

    return City(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : '',
      zipcode: json['zipcode'] is String ? json['zipcode'] : null,
      countryId: parseMany2oneId(json['country_id']),
      countryName: parseMany2oneName(json['country_id']),
      stateId: parseMany2oneId(json['state_id']),
      stateName: parseMany2oneName(json['state_id']),
    );
  }

  /// Convierte el City a JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (zipcode != null) 'zipcode': zipcode,
      if (countryId != null) 'country_id': [countryId, countryName],
      if (stateId != null) 'state_id': [stateId, stateName],
    };
  }

  /// Crea una copia del City con campos modificados
  City copyWith({
    int? id,
    String? name,
    String? zipcode,
    int? countryId,
    String? countryName,
    int? stateId,
    String? stateName,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      zipcode: zipcode ?? this.zipcode,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        zipcode,
        countryId,
        countryName,
        stateId,
        stateName,
      ];

  @override
  String toString() {
    return 'City(id: $id, name: $name, state: $stateName, country: $countryName)';
  }

  @override
  Map<String, dynamic> toVals() {
    return toJson();
  }

  /// Campos a solicitar en las consultas a Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'zipcode',
        'country_id',
        'state_id',
      ];

  /// Formato para mostrar en UI (Comuna, Región)
  String get displayName {
    if (stateName != null) {
      return '$name, $stateName';
    }
    return name;
  }
}

