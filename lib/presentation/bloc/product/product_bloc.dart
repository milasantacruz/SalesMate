import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/pricelist_repository.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/pricelist_item_model.dart';
import 'product_event.dart';
import 'product_state.dart';

/// BLoC para manejar la lógica de Productos
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;
  final PricelistRepository _pricelistRepository;

  ProductBloc(this._productRepository, this._pricelistRepository) : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<RefreshProducts>(_onRefreshProducts);
    on<SearchAndFilterProducts>(_onSearchAndFilterProducts);
    on<LoadProductsByType>(_onLoadProductsByType);
    on<SearchProducts>(_onSearchProducts);
    on<GetProductById>(_onGetProductById);
    on<LoadProductsWithPricelist>(_onLoadProductsWithPricelist);
    on<SearchProductsWithPricelist>(_onSearchProductsWithPricelist);
  }

  Future<void> _onLoadProducts(LoadProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      // Limpiar filtros y cargar productos
      _productRepository.setSearchParams(searchTerm: '', type: null);
      await _productRepository.loadRecords();
      final products = _productRepository.latestRecords;
      
      if (products.isEmpty) {
        emit(const ProductEmpty());
      } else {
        // ✅ NUEVO: Calcular precios desde tarifa de licencia
        final productsWithPrices = await _calculatePricesForProducts(products);
        emit(ProductLoaded(productsWithPrices));
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
        // ✅ NUEVO: Calcular precios desde tarifa de licencia
        final productsWithPrices = await _calculatePricesForProducts(products);
        emit(ProductLoaded(productsWithPrices));
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
        // ✅ NUEVO: Calcular precios desde tarifa de licencia
        final productsWithPrices = await _calculatePricesForProducts(products);
        emit(ProductFilteredByType(products: productsWithPrices, type: event.type));
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
        // ✅ NUEVO: Calcular precios desde tarifa de licencia
        final productsWithPrices = await _calculatePricesForProducts(products);
        emit(ProductSearchResult(products: productsWithPrices, searchTerm: event.searchTerm));
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

  Future<void> _onLoadProductsWithPricelist(
      LoadProductsWithPricelist event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      print('🛍️ PRODUCT_BLOC: Cargando productos con pricelist para partner ${event.partnerId}');
      
      // Obtener pricelist del partner
      final pricelistId = await _pricelistRepository.getPartnerPricelistId(event.partnerId);
      if (pricelistId == null) {
        print('⚠️ PRODUCT_BLOC: No se encontró pricelist para partner ${event.partnerId}, usando precios estándar');
        // Fallback a carga normal
        await _onLoadProducts(LoadProducts(), emit);
        return;
      }

      // Limpiar filtros y cargar productos
      _productRepository.setSearchParams(searchTerm: '', type: null);
      await _productRepository.loadRecords();
      final products = _productRepository.latestRecords;
      
      if (products.isEmpty) {
        emit(const ProductEmpty());
        return;
      }

      // Obtener items de pricelist
      final pricelistItems = await _pricelistRepository.getPricelistItems(pricelistId);
      print('💰 PRODUCT_BLOC: ${pricelistItems.length} items de pricelist encontrados');

      // Mapear productos con precios de pricelist
      final productsWithPricelist = await _mapProductsWithPricelist(products, pricelistItems);
      
      emit(ProductLoadedWithPricelist(
        products: productsWithPricelist, 
        pricelistId: pricelistId
      ));
    } catch (e) {
      print('❌ PRODUCT_BLOC: Error cargando productos con pricelist: $e');
      emit(ProductError('Error cargando productos con lista de precios: $e'));
    }
  }

  Future<void> _onSearchProductsWithPricelist(
      SearchProductsWithPricelist event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      print('🔍 PRODUCT_BLOC: Buscando productos con pricelist para partner ${event.partnerId}');
      
      // Obtener pricelist del partner
      final pricelistId = await _pricelistRepository.getPartnerPricelistId(event.partnerId);
      if (pricelistId == null) {
        print('⚠️ PRODUCT_BLOC: No se encontró pricelist para partner ${event.partnerId}, usando búsqueda estándar');
        // Fallback a búsqueda normal
        await _onSearchProducts(SearchProducts(searchTerm: event.searchTerm), emit);
        return;
      }

      // Buscar productos
      final products = await _productRepository.searchProducts(event.searchTerm);
      
      if (products.isEmpty) {
        emit(ProductEmpty(message: 'No se encontraron productos para "${event.searchTerm}"'));
        return;
      }

      // Obtener items de pricelist
      final pricelistItems = await _pricelistRepository.getPricelistItems(pricelistId);
      print('💰 PRODUCT_BLOC: ${pricelistItems.length} items de pricelist encontrados para búsqueda');

      // Mapear productos con precios de pricelist
      final productsWithPricelist = await _mapProductsWithPricelist(products, pricelistItems);
      
      emit(ProductSearchResultWithPricelist(
        products: productsWithPricelist, 
        searchTerm: event.searchTerm,
        pricelistId: pricelistId
      ));
    } catch (e) {
      print('❌ PRODUCT_BLOC: Error buscando productos con pricelist: $e');
      emit(ProductError('Error buscando productos con lista de precios: $e'));
    }
  }

  /// Mapea productos con sus precios de pricelist
  Future<List<Product>> _mapProductsWithPricelist(
      List<Product> products, List<PricelistItem> pricelistItems) async {
    final productsWithPricelist = <Product>[];
    
    for (final product in products) {
      // Buscar item de pricelist para este producto
      PricelistItem? pricelistItem;
      
      // Primero buscar por product_id específico
      pricelistItem = pricelistItems.firstWhere(
        (item) => item.productId == product.id,
        orElse: () => PricelistItem(
          id: 0, 
          name: '', 
          pricelistId: 0
        ),
      );
      
      // Si no se encuentra, buscar por product_tmpl_id
      if (pricelistItem.id == 0 && product.productTmplId != null) {
        print('🔍 PRODUCT_BLOC: No se encontró item de pricelist para producto ${product.id}, buscando por product_tmpl_id ${product.productTmplId}');
        pricelistItem = pricelistItems.firstWhere(
          (item) => item.productTmplId == product.productTmplId,
          orElse: () => PricelistItem(
            id: 0, 
            name: '', 
            pricelistId: 0
          ),
        );
      }
      
      double finalPrice = product.listPrice;
      
      // Aplicar precio de pricelist si existe
      if (pricelistItem.id != 0) {
        finalPrice = pricelistItem.calculatePrice(product.listPrice);
        print('💰 PRODUCT_BLOC: Producto ${product.name}: ${product.listPrice} -> $finalPrice (${pricelistItem.name})');
      }
      
      // Crear producto con precio actualizado
      final productWithPricelist = product.copyWith(
        listPrice: finalPrice,
        // Agregar información de pricelist si es necesario
      );
      
      productsWithPricelist.add(productWithPricelist);
    }
    
    return productsWithPricelist;
  }

  /// Calcula precios para una lista de productos usando la tarifa de la licencia
  /// 
  /// Usa getCalculatedPriceForProduct() que busca primero en cache (offline)
  /// y luego en Odoo si hay conexión.
  /// 
  /// [products] Lista de productos a calcular precios
  /// Retorna lista de productos con precios calculados (almacenados en listPrice)
  Future<List<Product>> _calculatePricesForProducts(List<Product> products) async {
    final productsWithCalculatedPrice = <Product>[];
    
    print('💰 PRODUCT_BLOC: Calculando precios para ${products.length} productos desde tarifa de licencia...');
    
    for (final product in products) {
      try {
        final calculatedPrice = await _pricelistRepository.getCalculatedPriceForProduct(
          productId: product.id,
          productTmplId: product.productTmplId,
          basePrice: product.listPrice,
        );
        
        // Usar precio calculado si existe, sino usar precio base
        final finalPrice = calculatedPrice ?? product.listPrice;
        
        // Reutilizar listPrice para almacenar precio calculado
        productsWithCalculatedPrice.add(
          product.copyWith(listPrice: finalPrice),
        );
      } catch (e) {
        print('⚠️ PRODUCT_BLOC: Error calculando precio para producto ${product.id}: $e');
        // En caso de error, mantener precio base
        productsWithCalculatedPrice.add(product);
      }
    }
    
    print('✅ PRODUCT_BLOC: ${productsWithCalculatedPrice.length} productos con precios calculados');
    return productsWithCalculatedPrice;
  }
}