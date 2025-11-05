import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo para representar un impuesto (account.tax)
class Tax extends Equatable implements OdooRecord {
  final int id;
  final String name;
  final double amount; // Porcentaje o monto fijo según amountType
  final String typeTaxUse; // 'sale', 'purchase', 'none'
  final int? companyId;
  final String amountType; // 'fixed', 'percent', 'group', 'division'
  final bool priceInclude; // Si el impuesto está incluido en el precio

  const Tax({
    required this.id,
    required this.name,
    required this.amount,
    required this.typeTaxUse,
    this.companyId,
    required this.amountType,
    required this.priceInclude,
  });

  /// Crea un Tax desde JSON
  factory Tax.fromJson(Map<String, dynamic> json) {
    try {
      // Parsear company_id (puede venir como List [id, name] o como int)
      int? parseCompanyId(dynamic value) {
        if (value == null || value == false) return null;
        if (value is int) return value;
        if (value is List && value.isNotEmpty) {
          return (value[0] as num?)?.toInt();
        }
        if (value is num) return value.toInt();
        return null;
      }

      return Tax(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        typeTaxUse: json['type_tax_use'] as String? ?? 'none',
        companyId: parseCompanyId(json['company_id']),
        amountType: json['amount_type'] as String? ?? 'percent',
        priceInclude: (json['price_include'] as bool?) ?? false,
      );
    } catch (e) {
      print('❌ TAX_MODEL: Error en fromJson: $e');
      print('❌ TAX_MODEL: JSON problemático: $json');
      rethrow;
    }
  }

  /// Convierte Tax a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type_tax_use': typeTaxUse,
      'company_id': companyId != null ? [companyId!, ''] : null,
      'amount_type': amountType,
      'price_include': priceInclude,
    };
  }

  /// Crea una copia con nuevos valores
  Tax copyWith({
    int? id,
    String? name,
    double? amount,
    String? typeTaxUse,
    int? companyId,
    String? amountType,
    bool? priceInclude,
  }) {
    return Tax(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      typeTaxUse: typeTaxUse ?? this.typeTaxUse,
      companyId: companyId ?? this.companyId,
      amountType: amountType ?? this.amountType,
      priceInclude: priceInclude ?? this.priceInclude,
    );
  }

  /// Verifica si el impuesto es de tipo porcentual
  bool get isPercent => amountType == 'percent';

  /// Verifica si el impuesto es de tipo fijo
  bool get isFixed => amountType == 'fixed';

  /// Verifica si el impuesto es para ventas
  bool get isSale => typeTaxUse == 'sale';

  @override
  List<Object?> get props => [
        id,
        name,
        amount,
        typeTaxUse,
        companyId,
        amountType,
        priceInclude,
      ];

  @override
  String toString() => 'Tax[$id]: $name (${amountType}: $amount, ${typeTaxUse})';

  @override
  Map<String, dynamic> toVals() {
    return toJson();
  }

  /// Campos a solicitar en Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'amount',
        'type_tax_use',
        'company_id',
        'amount_type',
        'price_include',
      ];
}

