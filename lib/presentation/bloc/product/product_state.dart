import 'package:equatable/equatable.dart';
import '../../../data/models/product_model.dart';

/// Estados base para el sistema de productos
abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial
class ProductInitial extends ProductState {}

/// Estado de carga durante operaciones
class ProductLoading extends ProductState {}

/// Estado cuando los productos están cargados
class ProductLoaded extends ProductState {
  final List<Product> products;

  const ProductLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

/// Estado cuando no hay productos
class ProductEmpty extends ProductState {
  final String message;

  const ProductEmpty({this.message = 'No se encontraron productos'});

  @override
  List<Object?> get props => [message];
}

/// Estado de error
class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Estado cuando se está realizando una operación
class ProductOperationInProgress extends ProductState {
  final String operation;

  const ProductOperationInProgress({required this.operation});

  @override
  List<Object?> get props => [operation];
}

/// Estado de resultado de búsqueda
class ProductSearchResult extends ProductState {
  final List<Product> products;
  final String searchTerm;

  const ProductSearchResult({required this.products, required this.searchTerm});

  @override
  List<Object?> get props => [products, searchTerm];
}

/// Estado de productos filtrados por tipo
class ProductFilteredByType extends ProductState {
  final List<Product> products;
  final String type;

  const ProductFilteredByType({required this.products, required this.type});

  @override
  List<Object?> get props => [products, type];
}

/// Estado cuando se obtiene un producto específico
class ProductRetrieved extends ProductState {
  final Product product;

  const ProductRetrieved({required this.product});

  @override
  List<Object?> get props => [product];
}
