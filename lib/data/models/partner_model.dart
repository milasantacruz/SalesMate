import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo Partner que representa un registro de res.partner en Odoo
class Partner extends Equatable implements OdooRecord {
  const Partner({
    required this.id,
    required this.name,
    this.vat,
    this.displayName,
    this.email,
    this.phone,
    this.isCompany = false,
    this.customerRank = 0,
    this.supplierRank = 0,
    this.active = true,
    this.type,
    this.parentId,
    this.parentName,
    this.commercialPartnerId,
    this.commercialPartnerName,
    this.street,
    this.street2,
    this.city,
    this.cityId,
    this.cityName,
    this.stateId,
    this.stateName,
    this.countryId,
    this.countryName,
    this.zip,
  });

  @override
  final int id;
  final String name;
  final String? vat;
  final String? displayName;
  final String? email;
  final String? phone;
  final bool isCompany;
  final int customerRank;
  final int supplierRank;
  final bool active;
  
  // Address fields
  final String? type; // 'contact', 'delivery', 'invoice', 'other', 'private'
  final int? parentId;
  final String? parentName;
  final int? commercialPartnerId;
  final String? commercialPartnerName;
  final String? street;
  final String? street2;
  final String? city;
  final int? cityId;
  final String? cityName;
  final int? stateId;
  final String? stateName;
  final int? countryId;
  final String? countryName;
  final String? zip;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (vat != null) 'vat': vat,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'is_company': isCompany,
      'customer_rank': customerRank,
      'supplier_rank': supplierRank,
      'active': active,
      if (type != null) 'type': type,
      if (parentId != null) 'parent_id': [parentId, parentName],
      if (commercialPartnerId != null) 'commercial_partner_id': [commercialPartnerId, commercialPartnerName],
      if (street != null) 'street': street,
      if (street2 != null) 'street2': street2,
      if (city != null) 'city': city,
      if (cityId != null) 'city_id': [cityId, cityName],
      if (stateId != null) 'state_id': [stateId, stateName],
      if (countryId != null) 'country_id': [countryId, countryName],
      if (zip != null) 'zip': zip,
    };
  }

  static Partner fromJson(Map<String, dynamic> json) {
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

    return Partner(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : '',
      vat: json['vat'] is String ? json['vat'] : null,
      displayName: json['display_name'] is String ? json['display_name'] : null,
      email: json['email'] is String ? json['email'] : null,
      phone: json['phone'] is String ? json['phone'] : null,
      isCompany: json['is_company'] as bool? ?? false,
      customerRank: json['customer_rank'] as int? ?? 0,
      supplierRank: json['supplier_rank'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      type: json['type'] is String ? json['type'] : null,
      parentId: parseMany2oneId(json['parent_id']),
      parentName: parseMany2oneName(json['parent_id']),
      commercialPartnerId: parseMany2oneId(json['commercial_partner_id']),
      commercialPartnerName: parseMany2oneName(json['commercial_partner_id']),
      street: json['street'] is String ? json['street'] : null,
      street2: json['street2'] is String ? json['street2'] : null,
      city: json['city'] is String ? json['city'] : null,
      cityId: parseMany2oneId(json['city_id']),
      cityName: parseMany2oneName(json['city_id']),
      stateId: parseMany2oneId(json['state_id']),
      stateName: parseMany2oneName(json['state_id']),
      countryId: parseMany2oneId(json['country_id']),
      countryName: parseMany2oneName(json['country_id']),
      zip: json['zip'] is String ? json['zip'] : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        vat,
        displayName,
        email,
        phone,
        isCompany,
        customerRank,
        supplierRank,
        active,
        type,
        parentId,
        parentName,
        commercialPartnerId,
        commercialPartnerName,
        street,
        street2,
        city,
        cityId,
        cityName,
        stateId,
        stateName,
        countryId,
        countryName,
        zip,
      ];

  /// Lista de campos que se deben obtener de Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'vat',
        'display_name',
        'email',
        'phone',
        'is_company',
        'customer_rank',
        'supplier_rank',
        'active',
        'type',
        'parent_id',
        'commercial_partner_id',
        'street',
        'street2',
        'city',
        'city_id',
        'state_id',
        'country_id',
        'zip',
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
    String? type,
    int? parentId,
    String? parentName,
    int? commercialPartnerId,
    String? commercialPartnerName,
    String? street,
    String? street2,
    String? city,
    int? cityId,
    String? cityName,
    int? stateId,
    String? stateName,
    int? countryId,
    String? countryName,
    String? zip,
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
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      commercialPartnerId: commercialPartnerId ?? this.commercialPartnerId,
      commercialPartnerName: commercialPartnerName ?? this.commercialPartnerName,
      street: street ?? this.street,
      street2: street2 ?? this.street2,
      city: city ?? this.city,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      zip: zip ?? this.zip,
    );
  }

  /// Verifica si el partner es un cliente
  bool get isCustomer => customerRank > 0;

  /// Verifica si el partner es un proveedor
  bool get isSupplier => supplierRank > 0;

  /// Verifica si el partner es tanto cliente como proveedor
  bool get isCustomerAndSupplier => isCustomer && isSupplier;

  /// Verifica si es una dirección de despacho
  bool get isDeliveryAddress => type == 'delivery';

  /// Verifica si es una dirección de facturación
  bool get isInvoiceAddress => type == 'invoice';

  /// Verifica si es un contacto principal
  bool get isMainContact => type == 'contact' || type == null;

  /// Obtiene la dirección completa formateada
  String get formattedAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (street2 != null && street2!.isNotEmpty) parts.add(street2!);
    
    final cityParts = <String>[];
    if (city != null && city!.isNotEmpty) {
      cityParts.add(city!);
    } else if (cityName != null && cityName!.isNotEmpty) {
      cityParts.add(cityName!);
    }
    if (stateName != null && stateName!.isNotEmpty) cityParts.add(stateName!);
    if (cityParts.isNotEmpty) parts.add(cityParts.join(', '));
    
    if (countryName != null && countryName!.isNotEmpty) parts.add(countryName!);
    if (zip != null && zip!.isNotEmpty) parts.add('CP: $zip');
    
    return parts.join('\n');
  }

  /// Obtiene la dirección en una línea
  String get singleLineAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (cityName != null && cityName!.isNotEmpty) parts.add(cityName!);
    if (stateName != null && stateName!.isNotEmpty) parts.add(stateName!);
    return parts.join(', ');
  }
}
