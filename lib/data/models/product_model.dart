import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo para representar un producto en Odoo
class Product extends Equatable implements OdooRecord {
  final int id;
  final String? defaultCode;
  final String name;
  final String type;
  final double listPrice;
  final int? uomId;
  final String? uomName;
  final List<int> taxesIds;
  final int? productTmplId;
  final bool isStorable;

  const Product({
    required this.id,
    this.defaultCode,
    required this.name,
    required this.type,
    required this.listPrice,
    this.uomId,
    this.uomName,
    this.taxesIds = const [],
    this.productTmplId,
    this.isStorable = false,
  });

  /// Crea un Product desde JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      // Odoo puede enviar 'false' para campos vacíos
      defaultCode: json['default_code'] is String ? json['default_code'] as String : null,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'product',
      listPrice: (json['list_price'] as num?)?.toDouble() ?? 0.0,
      uomId: json['uom_id'] is List 
          ? (json['uom_id'] as List)[0] as int
          : json['uom_id'] as int?,
      uomName: json['uom_id'] is List 
          ? (json['uom_id'] as List)[1] as String
          : null,
      taxesIds: (json['taxes_id'] as List<dynamic>?)
          ?.map((e) => e is List ? e[0] as int : e as int)
          .toList() ?? [],
      productTmplId: json['product_tmpl_id'] is List 
          ? (json['product_tmpl_id'] as List).isNotEmpty ? (json['product_tmpl_id'] as List)[0] as int? : null
          : json['product_tmpl_id'] as int?,
      isStorable: json['is_storable'] is bool
          ? json['is_storable'] as bool
          : (json['is_storable'] is String
              ? ((json['is_storable'] as String).toLowerCase() == 't' || (json['is_storable'] as String).toLowerCase() == 'true')
              : false),
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
      'uom_id': uomId != null ? [uomId!, uomName ?? ''] : null,
      'taxes_id': taxesIds.map((id) => [id, '']).toList(),
      'product_tmpl_id': productTmplId,
      'is_storable': isStorable,
    };
  }

  /// Crea una copia con nuevos valores
  Product copyWith({
    int? id,
    String? defaultCode,
    String? name,
    String? type,
    double? listPrice,
    int? uomId,
    String? uomName,
    List<int>? taxesIds,
    int? productTmplId,
    bool? isStorable,
  }) {
    return Product(
      id: id ?? this.id,
      defaultCode: defaultCode ?? this.defaultCode,
      name: name ?? this.name,
      type: type ?? this.type,
      listPrice: listPrice ?? this.listPrice,
      uomId: uomId ?? this.uomId,
      uomName: uomName ?? this.uomName,
      taxesIds: taxesIds ?? this.taxesIds,
      productTmplId: productTmplId ?? this.productTmplId,
      isStorable: isStorable ?? this.isStorable,
    );
  }

  // Getters de conveniencia
  bool get isService => type == 'service' && !isStorable;
  bool get isConsumable => type == 'consu' && !isStorable;
  bool get isProductStorable => type == 'consu' && isStorable;
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
        productTmplId,
      isStorable,
      ];

  @override
  Map<String, dynamic> toVals() {
    return toJson();
  }

  static List<String> get oFields => [
    'id',
    'default_code',
    'name',
    'type',
    'list_price',
    'uom_id',
    'taxes_id',
    'product_tmpl_id',
    'is_storable',
  ];
}