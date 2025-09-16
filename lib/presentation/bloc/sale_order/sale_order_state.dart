import 'package:equatable/equatable.dart';
import '../../../data/models/sale_order_model.dart';

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
