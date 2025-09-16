import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo Partner que representa un registro de res.partner en Odoo
class Partner extends Equatable implements OdooRecord {
  const Partner({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.isCompany = false,
    this.customerRank = 0,
    this.supplierRank = 0,
    this.active = true,
  });

  @override
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final bool isCompany;
  final int customerRank;
  final int supplierRank;
  final bool active;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'is_company': isCompany,
      'customer_rank': customerRank,
      'supplier_rank': supplierRank,
      'active': active,
    };
  }

  static Partner fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : '',
      email: json['email'] is String ? json['email'] : null,
      phone: json['phone'] is String ? json['phone'] : null,
      isCompany: json['is_company'] as bool? ?? false,
      customerRank: json['customer_rank'] as int? ?? 0,
      supplierRank: json['supplier_rank'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        isCompany,
        customerRank,
        supplierRank,
        active,
      ];

  /// Lista de campos que se deben obtener de Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'email',
        'phone',
        'is_company',
        'customer_rank',
        'supplier_rank',
        'active',
      ];

  @override
  String toString() => 'Partner[$id]: $name';

  @override
  Map<String, dynamic> toVals() {
    return toJson();
  }

  /// Crea una copia del Partner con campos modificados
  Partner copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    bool? isCompany,
    int? customerRank,
    int? supplierRank,
    bool? active,
  }) {
    return Partner(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isCompany: isCompany ?? this.isCompany,
      customerRank: customerRank ?? this.customerRank,
      supplierRank: supplierRank ?? this.supplierRank,
      active: active ?? this.active,
    );
  }

  /// Verifica si el partner es un cliente
  bool get isCustomer => customerRank > 0;

  /// Verifica si el partner es un proveedor
  bool get isSupplier => supplierRank > 0;

  /// Verifica si el partner es tanto cliente como proveedor
  bool get isCustomerAndSupplier => isCustomer && isSupplier;
}
