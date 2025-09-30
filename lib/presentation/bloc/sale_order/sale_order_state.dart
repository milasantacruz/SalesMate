import 'package:equatable/equatable.dart';
import '../../../data/models/sale_order_model.dart';
import '../../../data/models/order_totals_model.dart';

abstract class SaleOrderState extends Equatable {
  const SaleOrderState();

  @override
  List<Object> get props => [];
}

class SaleOrderInitial extends SaleOrderState {}

class SaleOrderLoading extends SaleOrderState {}

class SaleOrderLoaded extends SaleOrderState {
  final List<SaleOrder> saleOrders;

  const SaleOrderLoaded(this.saleOrders);

  @override
  List<Object> get props => [saleOrders];
}

class SaleOrderEmpty extends SaleOrderState {
  final String message;

  const SaleOrderEmpty({this.message = 'No se encontraron órdenes de venta'});

  @override
  List<Object> get props => [message];
}

class SaleOrderError extends SaleOrderState {
  final String message;

  const SaleOrderError(this.message);

  @override
  List<Object> get props => [message];
}

/// Estado cuando se está creando una orden
class SaleOrderCreating extends SaleOrderState {}

/// Estado cuando se creó una orden exitosamente
class SaleOrderCreated extends SaleOrderState {
  final int orderId;
  final Map<String, dynamic> orderData;

  const SaleOrderCreated({required this.orderId, required this.orderData});

  @override
  List<Object> get props => [orderId, orderData];
}

/// Estado cuando se está actualizando una orden
class SaleOrderUpdating extends SaleOrderState {
  final int orderId;

  const SaleOrderUpdating({required this.orderId});

  @override
  List<Object> get props => [orderId];
}

/// Estado cuando se actualizó una orden exitosamente
class SaleOrderUpdated extends SaleOrderState {
  final int orderId;
  final String newState;

  const SaleOrderUpdated({required this.orderId, required this.newState});

  @override
  List<Object> get props => [orderId, newState];
}

/// Estado cuando se están calculando totales
class SaleOrderCalculatingTotals extends SaleOrderState {}

/// Estado con totales calculados
class SaleOrderTotalsCalculated extends SaleOrderState {
  final OrderTotals totals;
  
  const SaleOrderTotalsCalculated({required this.totals});
  
  @override
  List<Object> get props => [totals];
}

/// Estado cuando se cargaron órdenes por partner
class SaleOrdersLoadedByPartner extends SaleOrderState {
  final List<SaleOrder> orders;
  final int partnerId;
  
  const SaleOrdersLoadedByPartner({
    required this.orders,
    required this.partnerId,
  });
  
  @override
  List<Object> get props => [orders, partnerId];
}

/// Estado cuando se cargó una orden específica
class SaleOrderLoadedById extends SaleOrderState {
  final SaleOrder order;
  
  const SaleOrderLoadedById({required this.order});
  
  @override
  List<Object> get props => [order];
}




