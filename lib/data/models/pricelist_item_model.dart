import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Modelo para representar un item de lista de precios (product.pricelist.item)
class PricelistItem extends Equatable implements OdooRecord {
  final int id;
  final String name;
  final int pricelistId;
  final int? productId;
  final int? productTmplId;
  final double? fixedPrice;
  final double? percentPrice;
  final double? minQuantity;
  final bool active;

  const PricelistItem({
    required this.id,
    required this.name,
    required this.pricelistId,
    this.productId,
    this.productTmplId,
    this.fixedPrice,
    this.percentPrice,
    this.minQuantity,
    this.active = true,
  });

  /// Crea un PricelistItem desde JSON
  factory PricelistItem.fromJson(Map<String, dynamic> json) {
    print('🔍 PRICELIST_ITEM: fromJson called with: $json');
    
    try {
      return PricelistItem(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        pricelistId: 0, // No se solicita en oFields, usar valor por defecto
        productId: json['product_id'] is List 
            ? (json['product_id'] as List).isNotEmpty ? (json['product_id'] as List)[0] as int? : null
            : json['product_id'] is bool 
                ? null 
                : json['product_id'] as int?,
        productTmplId: json['product_tmpl_id'] is List 
            ? (json['product_tmpl_id'] as List).isNotEmpty ? (json['product_tmpl_id'] as List)[0] as int? : null
            : json['product_tmpl_id'] as int?,
        fixedPrice: (json['fixed_price'] as num?)?.toDouble(),
        percentPrice: (json['percent_price'] as num?)?.toDouble(),
        minQuantity: (json['min_quantity'] as num?)?.toDouble(),
        active: true, // No se solicita en oFields, usar valor por defecto
      );
    } catch (e) {
      print('❌ PRICELIST_ITEM: Error en fromJson: $e');
      print('❌ PRICELIST_ITEM: JSON problemático: $json');
      rethrow;
    }
  }

  /// Convierte PricelistItem a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pricelist_id': [pricelistId, ''],
      'product_id': productId != null ? [productId!, ''] : null,
      'product_tmpl_id': productTmplId != null ? [productTmplId!, ''] : null,
      'fixed_price': fixedPrice,
      'percent_price': percentPrice,
      'min_quantity': minQuantity,
      'active': active,
    };
  }

  /// Crea una copia con nuevos valores
  PricelistItem copyWith({
    int? id,
    String? name,
    int? pricelistId,
    int? productId,
    int? productTmplId,
    double? fixedPrice,
    double? percentPrice,
    double? minQuantity,
    bool? active,
  }) {
    return PricelistItem(
      id: id ?? this.id,
      name: name ?? this.name,
      pricelistId: pricelistId ?? this.pricelistId,
      productId: productId ?? this.productId,
      productTmplId: productTmplId ?? this.productTmplId,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      percentPrice: percentPrice ?? this.percentPrice,
      minQuantity: minQuantity ?? this.minQuantity,
      active: active ?? this.active,
    );
  }

  /// Verifica si el item tiene precio fijo
  bool get hasFixedPrice => fixedPrice != null && fixedPrice! > 0;

  /// Verifica si el item tiene precio porcentual
  bool get hasPercentPrice => percentPrice != null && percentPrice! != 0;

  /// Calcula el precio aplicando el porcentaje sobre un precio base
  double calculatePrice(double basePrice) {
    if (hasFixedPrice) {
      print('🔍 PRICELIST_ITEM: hasFixedPrice: ${fixedPrice!}');
      return fixedPrice!;
    } else if (hasPercentPrice) {
      return basePrice * (1 + (percentPrice! / 100));
    }
    return basePrice;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        pricelistId,
        productId,
        productTmplId,
        fixedPrice,
        percentPrice,
        minQuantity,
        active,
      ];

  @override
  String toString() => 'PricelistItem[$id]: $name (Pricelist: $pricelistId)';

  @override
  Map<String, dynamic> toVals() {
    return toJson();
  }

  static List<String> get oFields => [
    'id',
    'name',
    'product_id',
    'product_tmpl_id',
    'fixed_price',
    'percent_price',
    'min_quantity',
  ];
}
