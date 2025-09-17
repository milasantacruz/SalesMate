import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/product_repository.dart';
import 'product_event.dart';
import 'product_state.dart';

/// BLoC para manejar la lógica de Productos
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;

  ProductBloc(this._productRepository) : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<RefreshProducts>(_onRefreshProducts);
    on<SearchAndFilterProducts>(_onSearchAndFilterProducts);
    on<LoadProductsByType>(_onLoadProductsByType);
    on<SearchProducts>(_onSearchProducts);
    on<GetProductById>(_onGetProductById);
  }

  Future<void> _onLoadProducts(LoadProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      await _productRepository.loadRecords();
      final products = _productRepository.latestRecords;
      if (products.isEmpty) {
        emit(const ProductEmpty());
      } else {
        emit(ProductLoaded(products));
      }
    } catch (e) {
      emit(ProductError('Error cargando productos: $e'));
    }
  }

  Future<void> _onRefreshProducts(RefreshProducts event, Emitter<ProductState> emit) async {
    // Re-usa la lógica de _onLoadProducts para refrescar
    await _onLoadProducts(LoadProducts(), emit);
  }

  Future<void> _onSearchAndFilterProducts(
      SearchAndFilterProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      // Configurar los parámetros de búsqueda
      _productRepository.setSearchParams(
        searchTerm: event.searchTerm,
        type: event.type,
      );
      
      // Cargar los datos con los filtros aplicados
      await _productRepository.loadRecords();
      final products = _productRepository.latestRecords;
      if (products.isEmpty) {
        emit(const ProductEmpty(
            message: 'No se encontraron resultados para los filtros aplicados'));
      } else {
        emit(ProductLoaded(products));
      }
    } catch (e) {
      emit(ProductError('Error buscando y filtrando productos: $e'));
    }
  }

  Future<void> _onLoadProductsByType(
      LoadProductsByType event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      final products = await _productRepository.getProductsByType(event.type);
      if (products.isEmpty) {
        emit(ProductEmpty(message: 'No se encontraron productos de tipo ${event.type}'));
      } else {
        emit(ProductFilteredByType(products: products, type: event.type));
      }
    } catch (e) {
      emit(ProductError('Error cargando productos por tipo: $e'));
    }
  }

  Future<void> _onSearchProducts(SearchProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      final products = await _productRepository.searchProducts(event.searchTerm);
      if (products.isEmpty) {
        emit(ProductEmpty(message: 'No se encontraron productos para "${event.searchTerm}"'));
      } else {
        emit(ProductSearchResult(products: products, searchTerm: event.searchTerm));
      }
    } catch (e) {
      emit(ProductError('Error buscando productos: $e'));
    }
  }

  Future<void> _onGetProductById(GetProductById event, Emitter<ProductState> emit) async {
    emit(ProductOperationInProgress(operation: 'Obteniendo producto'));
    try {
      final product = await _productRepository.getProductById(event.id);
      if (product != null) {
        emit(ProductRetrieved(product: product));
      } else {
        emit(const ProductError('Producto no encontrado'));
      }
    } catch (e) {
      emit(ProductError('Error obteniendo producto: $e'));
    }
  }
}
