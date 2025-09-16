import 'package:equatable/equatable.dart';

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
