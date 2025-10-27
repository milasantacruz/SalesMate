import 'package:equatable/equatable.dart';
import 'sale_order_line_model.dart';

/// Modelo para crear una nueva orden de venta
class CreateSaleOrderRequest extends Equatable {
  final int? partnerId;
  final String? partnerName;
  final String? partnerDocument;
  final String? deliveryAddress;
  final String dateOrder;
  final int userId; // Re-agregado
  final List<SaleOrderLine> orderLines;
  final String state;
  final int? partnerShippingId;

  const CreateSaleOrderRequest({
    this.partnerId,
    this.partnerName,
    this.partnerDocument,
    this.deliveryAddress,
    required this.dateOrder,
    required this.userId, // Re-agregado
    required this.orderLines,
    this.state = 'draft',
    this.partnerShippingId,
  });

  /// Convierte a JSON para enviar a Odoo
  Map<String, dynamic> toJson() {
    final json = {
      'partner_id': partnerId,
      'date_order': dateOrder,
      'user_id': userId, // Re-agregado
      'state': state,
      'order_line':
          orderLines.map((line) => [0, 0, line.toCreateJson()]).toList(),
    };
    
    // Solo agregar partner_shipping_id si existe
    if (partnerShippingId != null) {
      json['partner_shipping_id'] = partnerShippingId;
    }
    
    return json;
  }

  /// Crea una copia con nuevos valores
  CreateSaleOrderRequest copyWith({
    int? partnerId,
    String? partnerName,
    String? partnerDocument,
    String? deliveryAddress,
    String? dateOrder,
    int? userId, // Re-agregado
    List<SaleOrderLine>? orderLines,
    String? state,
    int? partnerShippingId,
  }) {
    return CreateSaleOrderRequest(
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerDocument: partnerDocument ?? this.partnerDocument,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      dateOrder: dateOrder ?? this.dateOrder,
      userId: userId ?? this.userId, // Re-agregado
      orderLines: orderLines ?? this.orderLines,
      state: state ?? this.state,
      partnerShippingId: partnerShippingId ?? this.partnerShippingId,
    );
  }

  /// Calcula el subtotal de todos los productos
  double get subtotal {
    return orderLines.fold(0.0, (sum, line) => sum + line.subtotal);
  }

  /// Calcula el total de impuestos (simplificado - en producción se calcularía correctamente)
  double get taxAmount {
    // Simplificado: asumimos 19% de impuestos
    return subtotal * 0.19;
  }

  /// Calcula el total final
  double get total {
    return subtotal + taxAmount;
  }

  /// Valida si la request es válida para crear
  bool get isValid {
    return partnerId != null && 
           orderLines.isNotEmpty && 
           orderLines.every((line) => line.quantity > 0);
  }

  /// Obtiene errores de validación
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (partnerId == null) {
      errors.add('Debe seleccionar un cliente');
    }
    
    if (orderLines.isEmpty) {
      errors.add('Debe agregar al menos un producto');
    }
    
    for (int i = 0; i < orderLines.length; i++) {
      final line = orderLines[i];
      if (line.quantity <= 0) {
        errors.add('La cantidad del producto "${line.productName}" debe ser mayor a 0');
      }
    }
    
    return errors;
  }

  @override
  List<Object?> get props => [
        partnerId,
        partnerName,
        partnerDocument,
        deliveryAddress,
        dateOrder,
        userId, // Re-agregado
        orderLines,
        state,
        partnerShippingId,
      ];
}


