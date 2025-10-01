import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_test/data/models/sale_order_line_model.dart';

/// Modelo para representar una Orden de Venta de Odoo (sale.order)
class SaleOrder extends Equatable implements OdooRecord {
  final int id;
  final String name;
  final int? partnerId;
  final String? partnerName;
  final String dateOrder;
  final double amountTotal;
  final String state;
  final List<int> orderLineIds;
  final List<SaleOrderLine> orderLines;

  const SaleOrder({
    required this.id,
    required this.name,
    this.partnerId,
    this.partnerName,
    required this.dateOrder,
    required this.amountTotal,
    required this.state,
    required this.orderLineIds,
    this.orderLines = const [],
  });

  /// Crea una SaleOrder desde JSON
  factory SaleOrder.fromJson(Map<String, dynamic> json) {
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

    return SaleOrder(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : 'N/A',
      partnerId: parseMany2oneId(json['partner_id']),
      partnerName: parseMany2oneName(json['partner_id']),
      dateOrder: json['date_order'] is String ? json['date_order'] : '',
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] is String ? json['state'] : 'unknown',
      orderLineIds: (json['order_line'] as List<dynamic>?)
              ?.map((id) => id as int)
              .toList() ??
          [],
      orderLines: const [],
    );
  }

  /// Convierte SaleOrder a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'partner_id': partnerId != null ? [partnerId, partnerName] : false,
      'date_order': dateOrder,
      'amount_total': amountTotal,
      'state': state,
      'order_line': orderLineIds,
    };
  }

  SaleOrder copyWith({
    int? id,
    String? name,
    int? partnerId,
    String? partnerName,
    String? dateOrder,
    double? amountTotal,
    String? state,
    List<int>? orderLineIds,
    List<SaleOrderLine>? orderLines,
  }) {
    return SaleOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      dateOrder: dateOrder ?? this.dateOrder,
      amountTotal: amountTotal ?? this.amountTotal,
      state: state ?? this.state,
      orderLineIds: orderLineIds ?? this.orderLineIds,
      orderLines: orderLines ?? this.orderLines,
    );
  }

  /// Convierte SaleOrder a valores para Odoo (requerido por OdooRecord)
  Map<String, dynamic> toVals() {
    return {
      'name': name,
      'partner_id': partnerId,
      'date_order': dateOrder,
      'amount_total': amountTotal,
      'state': state,
      'order_line': orderLineIds,
    };
  }

  /// Campos que se solicitan a Odoo
  static List<String> get oFields => [
        'id',
        'name',
        'partner_id',
        'date_order',
        'amount_total',
        'state',
        'order_line',
      ];

  @override
  List<Object?> get props => [
        id,
        name,
        partnerId,
        partnerName,
        dateOrder,
        amountTotal,
        state,
        orderLineIds,
        orderLines,
      ];
}



