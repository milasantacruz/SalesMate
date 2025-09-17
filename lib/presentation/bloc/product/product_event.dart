import 'package:equatable/equatable.dart';

/// Eventos base para el sistema de productos
abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para cargar todos los productos
class LoadProducts extends ProductEvent {}

/// Evento para refrescar la lista de productos
class RefreshProducts extends ProductEvent {}

/// Evento para buscar y filtrar productos
class SearchAndFilterProducts extends ProductEvent {
  final String searchTerm;
  final String? type;

  const SearchAndFilterProducts({required this.searchTerm, this.type});

  @override
  List<Object?> get props => [searchTerm, type];
}

/// Evento para cargar productos por tipo
class LoadProductsByType extends ProductEvent {
  final String type;

  const LoadProductsByType({required this.type});

  @override
  List<Object?> get props => [type];
}

/// Evento para buscar productos por término
class SearchProducts extends ProductEvent {
  final String searchTerm;

  const SearchProducts({required this.searchTerm});

  @override
  List<Object?> get props => [searchTerm];
}

/// Evento para obtener un producto por ID
class GetProductById extends ProductEvent {
  final int id;

  const GetProductById({required this.id});

  @override
  List<Object?> get props => [id];
}
