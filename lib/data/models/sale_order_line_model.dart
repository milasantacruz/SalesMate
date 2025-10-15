import 'package:equatable/equatable.dart';

/// Modelo para representar una línea de pedido de venta (sale.order.line)
class SaleOrderLine extends Equatable {
  final int? id; // null para nuevas líneas
  final int productId;
  final String productName;
  final String? productCode;
  final double quantity;
  final double priceUnit;
  final double priceSubtotal;
  final List<int> taxesIds;
  
  // Campos para totales calculados por Odoo
  final double? priceTax;          // Impuestos de la línea
  final double? priceTotal;        // Total de la línea

  const SaleOrderLine({
    this.id,
    required this.productId,
    required this.productName,
    this.productCode,
    required this.quantity,
    required this.priceUnit,
    required this.priceSubtotal,
    required this.taxesIds,
    this.priceTax,
    this.priceTotal,
  });

  /// Crea una SaleOrderLine desde JSON
  factory SaleOrderLine.fromJson(Map<String, dynamic> json) {
    print('🔍 SALE_ORDER_LINE: Parsing JSON: $json');
    
    final id = json['id'] as int?;
    print('🔍 SALE_ORDER_LINE: Parsed ID: $id (type: ${id.runtimeType})');
    
    return SaleOrderLine(
      id: id,
      productId: json['product_id'] is List 
          ? (json['product_id'] as List)[0] as int
          : json['product_id'] as int,
      productName: json['product_id'] is List && (json['product_id'] as List).length > 1
          ? (json['product_id'] as List)[1] as String
          : json['name'] as String? ?? '',
      productCode: json['product_code'] as String?,
      quantity: (json['product_uom_qty'] as num?)?.toDouble() ?? 0.0,
      priceUnit: (json['price_unit'] as num?)?.toDouble() ?? 0.0,
      priceSubtotal: (json['price_subtotal'] as num?)?.toDouble() ?? 0.0,
      taxesIds: (json['tax_id'] as List<dynamic>?)?.map((id) => id as int).toList() ?? [],
      priceTax: (json['price_tax'] as num?)?.toDouble(),
      priceTotal: (json['price_total'] as num?)?.toDouble(),
    );
  }

  /// Convierte SaleOrderLine a JSON para crear en Odoo
  Map<String, dynamic> toCreateJson() {
    return {
      'product_id': productId,
      'product_uom_qty': quantity,
      'price_unit': priceUnit,
    };
  }

  /// Convierte SaleOrderLine a JSON completo
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': [productId, productName],
      'product_code': productCode,
      'product_uom_qty': quantity,
      'price_unit': priceUnit,
      'price_subtotal': priceSubtotal,
      'tax_id': taxesIds,
      'price_tax': priceTax,
      'price_total': priceTotal,
    };
  }

  /// Crea una copia con nuevos valores
  SaleOrderLine copyWith({
    int? id,
    int? productId,
    String? productName,
    String? productCode,
    double? quantity,
    double? priceUnit,
    double? priceSubtotal,
    List<int>? taxesIds,
    double? priceTax,
    double? priceTotal,
  }) {
    return SaleOrderLine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      quantity: quantity ?? this.quantity,
      priceUnit: priceUnit ?? this.priceUnit,
      priceSubtotal: priceSubtotal ?? this.priceSubtotal,
      taxesIds: taxesIds ?? this.taxesIds,
      priceTax: priceTax ?? this.priceTax,
      priceTotal: priceTotal ?? this.priceTotal,
    );
  }

  /// Calcula el subtotal de la línea
  double get subtotal => quantity * priceUnit;

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productCode,
        quantity,
        priceUnit,
        priceSubtotal,
        taxesIds,
        priceTax,
        priceTotal,
      ];
}
