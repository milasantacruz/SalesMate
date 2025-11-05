import 'package:equatable/equatable.dart';

/// Modelo para representar los totales calculados de una orden
class OrderTotals extends Equatable {
  final double amountUntaxed;  // Subtotal sin impuestos
  final double amountTax;      // Total de impuestos
  final double amountTotal;    // Total final
  final List<TaxGroup> taxGroups; // Impuestos agrupados
  
  const OrderTotals({
    required this.amountUntaxed,
    required this.amountTax,
    required this.amountTotal,
    required this.taxGroups,
  });
  
  factory OrderTotals.fromJson(Map<String, dynamic> json) {
    return OrderTotals(
      amountUntaxed: (json['amount_untaxed'] ?? 0.0).toDouble(),
      amountTax: (json['amount_tax'] ?? 0.0).toDouble(),
      amountTotal: (json['amount_total'] ?? 0.0).toDouble(),
      taxGroups: (json['tax_groups'] as List<dynamic>?)
          ?.map((group) => TaxGroup.fromJson(group))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'amount_untaxed': amountUntaxed,
      'amount_tax': amountTax,
      'amount_total': amountTotal,
      'tax_groups': taxGroups.map((group) => group.toJson()).toList(),
    };
  }
  
  @override
  List<Object> get props => [amountUntaxed, amountTax, amountTotal, taxGroups];
}

/// Modelo para representar un grupo de impuestos
class TaxGroup extends Equatable {
  final String name;
  final double amount;
  final double base;
  final double? percentage; // Porcentaje del impuesto (null si es fijo)
  
  const TaxGroup({
    required this.name,
    required this.amount,
    required this.base,
    this.percentage,
  });
  
  factory TaxGroup.fromJson(Map<String, dynamic> json) {
    return TaxGroup(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      base: (json['base'] ?? 0.0).toDouble(),
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'base': base,
      'percentage': percentage,
    };
  }
  
  @override
  List<Object?> get props => [name, amount, base, percentage];
}
