import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_sales_app/data/models/sale_order_line_model.dart';

/// Modelo para representar una Orden de Venta de Odoo (sale.order)
class SaleOrder extends Equatable implements OdooRecord {
  final int id;
  final String name;
  final int? partnerId;
  final String? partnerName;
  final int? partnerShippingId;
  final String? partnerShippingName;
  final String dateOrder;
  final double amountTotal;
  final String state;
  final List<int> orderLineIds;
  final List<SaleOrderLine> orderLines;
  
  // Campos de auditoría automáticos de Odoo
  final int? userId;
  final String? userName;
  final int createUid;
  final String? createUserName;
  final String createDate;
  final int? writeUid;
  final String? writeUserName;
  final String? writeDate;

  const SaleOrder({
    required this.id,
    required this.name,
    this.partnerId,
    this.partnerName,
    this.partnerShippingId,
    this.partnerShippingName,
    required this.dateOrder,
    required this.amountTotal,
    required this.state,
    required this.orderLineIds,
    this.orderLines = const [],
    this.userId,
    this.userName,
    required this.createUid,
    this.createUserName,
    required this.createDate,
    this.writeUid,
    this.writeUserName,
    this.writeDate,
  });

  /// Crea una SaleOrder desde JSON
  factory SaleOrder.fromJson(Map<String, dynamic> json) {
    // Helper robusto para parsear campos de relación (Many2one)
    // ✅ MEJORADO: Acepta tanto List [id, name] como int directamente
    int? parseMany2oneId(dynamic value) {
      if (value == null || value == false) return null;
      
      // Caso 1: Es un entero directo (desde cache offline)
      if (value is int) {
        return value;
      }
      
      // Caso 2: Es una List [id, name] (desde Odoo o cache enriquecido)
      if (value is List && value.isNotEmpty) {
        try {
          return (value[0] as num?)?.toInt();
        } catch (e) {
          print('⚠️ SALE_ORDER_MODEL: Error parseando ID Many2one: $value');
          return null;
        }
      }
      
      // Caso 3: Es un num (double, etc.)
      if (value is num) return value.toInt();
      
      return null;
    }

    String? parseMany2oneName(dynamic value) {
      if (value == null || value == false) return null;
      
      // ✅ MEJORADO: Si es int, intentar obtener nombre desde cache (si está disponible)
      if (value is int) {
        // Por ahora retornar null, pero en el futuro podríamos buscar en cache
        return null;
      }
      
      // Formato estándar de Odoo: List [id, name]
      if (value is List && value.length > 1) {
        return value[1] as String?;
      }
      
      return null;
    }

    // Log de debug para campos de auditoría
    if (json.containsKey('create_uid')) {
      //print('🔍 SALE_ORDER_MODEL: create_uid raw value: ${json['create_uid']} (type: ${json['create_uid'].runtimeType})');
      //print('🔍 SALE_ORDER_MODEL: create_date raw value: ${json['create_date']} (type: ${json['create_date'].runtimeType})');
     // print('🔍 SALE_ORDER_MODEL: write_uid raw value: ${json['write_uid']} (type: ${json['write_uid'].runtimeType})');
      //print('🔍 SALE_ORDER_MODEL: user_id raw value: ${json['user_id']} (type: ${json['user_id'].runtimeType})');
    }

    return SaleOrder(
      id: json['id'] as int,
      name: json['name'] is String ? json['name'] : 'N/A',
      partnerId: parseMany2oneId(json['partner_id']),
      partnerName: parseMany2oneName(json['partner_id']),
      partnerShippingId: parseMany2oneId(json['partner_shipping_id']),
      partnerShippingName: parseMany2oneName(json['partner_shipping_id']),
      dateOrder: json['date_order'] is String ? json['date_order'] : '',
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] is String ? json['state'] : 'unknown',
      orderLineIds: (json['order_line'] as List<dynamic>?)
              ?.map((id) => id as int)
              .toList() ??
          [],
      // ✅ BUG-007: Cargar orderLines desde JSON si están disponibles
      orderLines: _parseOrderLinesFromJson(json),
      // Campos de auditoría
      userId: parseMany2oneId(json['user_id']),
      userName: parseMany2oneName(json['user_id']),
      createUid: parseMany2oneId(json['create_uid']) ?? 0,
      createUserName: parseMany2oneName(json['create_uid']),
      createDate: json['create_date'] is String ? json['create_date'] : 
                   json['create_date'] is DateTime ? json['create_date'].toString() : '',
      writeUid: parseMany2oneId(json['write_uid']),
      writeUserName: parseMany2oneName(json['write_uid']),
      writeDate: json['write_date'] is String ? json['write_date'] : 
                 json['write_date'] is DateTime ? json['write_date'].toString() : null,
    );
  }

  /// Convierte SaleOrder a JSON
  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'name': name,
      'partner_id': partnerId != null ? [partnerId, partnerName] : false,
      'partner_shipping_id': partnerShippingId != null ? [partnerShippingId, partnerShippingName] : false,
      'date_order': dateOrder,
      'amount_total': amountTotal,
      'state': state,
      'order_line': orderLineIds,
      // ✅ BUG-007: Incluir orderLines en JSON para cache offline
      'order_lines': orderLines.map((line) => line.toJson()).toList(),
      // Campos de auditoría
      'user_id': userId != null ? [userId, userName] : false,
      'create_uid': createUid,
      'create_date': createDate,
      'write_uid': writeUid,
      'write_date': writeDate,
    };
    return json;
  }

  SaleOrder copyWith({
    int? id,
    String? name,
    int? partnerId,
    String? partnerName,
    int? partnerShippingId,
    String? partnerShippingName,
    String? dateOrder,
    double? amountTotal,
    String? state,
    List<int>? orderLineIds,
    List<SaleOrderLine>? orderLines,
    int? userId,
    String? userName,
    int? createUid,
    String? createUserName,
    String? createDate,
    int? writeUid,
    String? writeUserName,
    String? writeDate,
  }) {
    return SaleOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerShippingId: partnerShippingId ?? this.partnerShippingId,
      partnerShippingName: partnerShippingName ?? this.partnerShippingName,
      dateOrder: dateOrder ?? this.dateOrder,
      amountTotal: amountTotal ?? this.amountTotal,
      state: state ?? this.state,
      orderLineIds: orderLineIds ?? this.orderLineIds,
      orderLines: orderLines ?? this.orderLines,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createUid: createUid ?? this.createUid,
      createUserName: createUserName ?? this.createUserName,
      createDate: createDate ?? this.createDate,
      writeUid: writeUid ?? this.writeUid,
      writeUserName: writeUserName ?? this.writeUserName,
      writeDate: writeDate ?? this.writeDate,
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
        'partner_shipping_id',
        'date_order',
        'amount_total',
        'state',
        'order_line',
        // Campos de auditoría automáticos
        'user_id',
        'create_uid',
        'create_date',
        'write_uid',
        'write_date',
      ];

  @override
  List<Object?> get props => [
        id,
        name,
        partnerId,
        partnerName,
        partnerShippingId,
        partnerShippingName,
        dateOrder,
        amountTotal,
        state,
        orderLineIds,
        orderLines,
        userId,
        userName,
        createUid,
        createUserName,
        createDate,
        writeUid,
        writeUserName,
        writeDate,
      ];
}

/// ✅ BUG-007: Helper para parsear orderLines de forma robusta
List<SaleOrderLine> _parseOrderLinesFromJson(Map<String, dynamic> json) {
  try {
    // Verificar si existe order_lines
    if (!json.containsKey('order_lines')) {
      return const [];
    }

    final orderLinesRaw = json['order_lines'];

    // Si es String (serializado incorrectamente), intentar parsear
    if (orderLinesRaw is String) {
      print('⚠️ SALE_ORDER_MODEL: order_lines es String, intentando parsear...');
      try {
        final decoded = jsonDecode(orderLinesRaw);
        if (decoded is List) {
          final linesFromString = decoded
              .map((line) {
                try {
                  if (line is Map) {
                    return SaleOrderLine.fromJson(Map<String, dynamic>.from(line));
                  }
                  return null;
                } catch (e) {
                  print('⚠️ SALE_ORDER_MODEL: Error parseando línea (string->json): $e');
                  return null;
                }
              })
              .whereType<SaleOrderLine>()
              .toList();
          return linesFromString;
        }
      } catch (_) {}
      return const [];
    }

    // Si es List, procesar
    if (orderLinesRaw is List) {
      final lines = orderLinesRaw
          .map((line) {
            try {
              if (line is Map) {
                return SaleOrderLine.fromJson(Map<String, dynamic>.from(line));
              }
              return null;
            } catch (e) {
              print('⚠️ SALE_ORDER_MODEL: Error parseando línea: $e');
              return null;
            }
          })
          .whereType<SaleOrderLine>()
          .toList();
      return lines;
    }

    return const [];
  } catch (e) {
    print('⚠️ SALE_ORDER_MODEL: Error parseando orderLines: $e');
    return const [];
  }
}



