import 'package:equatable/equatable.dart';
import '../../../data/models/sale_order_line_model.dart';

abstract class SaleOrderEvent extends Equatable {
  const SaleOrderEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all sale orders
class LoadSaleOrders extends SaleOrderEvent {}

/// Event to refresh the list of sale orders
class RefreshSaleOrders extends SaleOrderEvent {}

/// Event to search and filter sale orders
class SearchAndFilterSaleOrders extends SaleOrderEvent {
  final String searchTerm;
  final String? state;

  const SearchAndFilterSaleOrders({required this.searchTerm, this.state});

  @override
  List<Object?> get props => [searchTerm, state];
}

/// Event to create a new sale order
class CreateSaleOrder extends SaleOrderEvent {
  final Map<String, dynamic> orderData;

  const CreateSaleOrder({required this.orderData});

  @override
  List<Object?> get props => [orderData];
}

/// Event to update the state of an order
class UpdateOrderState extends SaleOrderEvent {
  final int orderId;
  final String newState;

  const UpdateOrderState({required this.orderId, required this.newState});

  @override
  List<Object?> get props => [orderId, newState];
}

/// Evento para calcular totales de una orden
class CalculateOrderTotals extends SaleOrderEvent {
  final int partnerId;
  final List<SaleOrderLine> orderLines;
  
  const CalculateOrderTotals({
    required this.partnerId,
    required this.orderLines,
  });
  
  @override
  List<Object?> get props => [partnerId, orderLines];
}

/// Evento para limpiar el cache de totales
class ClearTotalsCache extends SaleOrderEvent {}

/// Event to load sale orders by partner
class LoadSaleOrdersByPartner extends SaleOrderEvent {
  final int partnerId;
  
  const LoadSaleOrdersByPartner({required this.partnerId});
  
  @override
  List<Object?> get props => [partnerId];
}

/// Event to load a specific sale order by ID
class LoadSaleOrderById extends SaleOrderEvent {
  final int orderId;
  
  const LoadSaleOrderById({required this.orderId});
  
  @override
  List<Object?> get props => [orderId];
}

/// Event to update an existing sale order
class UpdateSaleOrder extends SaleOrderEvent {
  final int orderId;
  final Map<String, dynamic> orderData;
  
  const UpdateSaleOrder({
    required this.orderId,
    required this.orderData,
  });
  
  @override
  List<Object?> get props => [orderId, orderData];
}





