import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo para representar un Producto de Odoo (product.product)
class Product extends Equatable implements OdooRecord {
  final int id;
  final String? defaultCode;
  final String name;
  final String type;
  final double listPrice;
  final int? uomId;
  final String? uomName;
  final List<int> taxesIds;

  const Product({
    required this.id,
    this.defaultCode,
    required this.name,
    required this.type,
    required this.listPrice,
    this.uomId,
    this.uomName,
    required this.taxesIds,
  });

  /// Crea un Product desde JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper robusto para parsear campos de relación (Many2one)
    int? parseMany2oneId(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value[0] as int?;
      }
      return null;
    }

    String? parseMany2oneName(dynamic value) {
      if (value is List && value.length > 1) {
        return value[1] as String?;
      }
      return null;
    }

    // Helper para parsear Many2many (taxes_id)
    List<int> parseMany2manyIds(dynamic value) {
      if (value is List) {
        return value.map((id) => id as int).toList();
      }
      return [];
    }

    return Product(
      id: json['id'] as int,
      defaultCode: json['default_code'] is String ? json['default_code'] : null,
      name: json['name'] is String ? json['name'] : '',
      type: json['type'] is String ? json['type'] : 'consu',
      listPrice: (json['list_price'] as num?)?.toDouble() ?? 0.0,
      uomId: parseMany2oneId(json['uom_id']),
      uomName: parseMany2oneName(json['uom_id']),
      taxesIds: parseMany2manyIds(json['taxes_id']),
    );
  }

  /// Convierte Product a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'default_code': defaultCode,
      'name': name,
      'type': type,
      'list_price': listPrice,
      'uom_id': uomId != null ? [uomId, uomName] : false,
      'taxes_id': taxesIds,
    };
  }

  /// Convierte Product a valores para Odoo (requerido por OdooRecord)
  Map<String, dynamic> toVals() {
    return {
      'default_code': defaultCode,
      'name': name,
      'type': type,
      'list_price': listPrice,
      'uom_id': uomId,
      'taxes_id': taxesIds,
    };
  }

  /// Campos que se solicitan a Odoo
  static List<String> get oFields => [
        'id',
        'default_code',
        'name',
        'type',
        'list_price',
        'uom_id',
        'taxes_id',
      ];

  /// Getters útiles
  bool get isService => type == 'service';
  bool get isConsumable => type == 'consu';
  bool get isStorable => type == 'product';
  bool get hasDefaultCode => defaultCode != null && defaultCode!.isNotEmpty;
  String get displayName => hasDefaultCode ? '[$defaultCode] $name' : name;

  @override
  List<Object?> get props => [
        id,
        defaultCode,
        name,
        type,
        listPrice,
        uomId,
        uomName,
        taxesIds,
      ];
}
