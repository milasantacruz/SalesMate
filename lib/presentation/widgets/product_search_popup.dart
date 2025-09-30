import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/product/product_event.dart';
import '../bloc/product/product_state.dart';
import '../../../data/models/product_model.dart';
import 'product_addon_widget.dart';

/// Popup para buscar y seleccionar productos
class ProductSearchPopup extends StatefulWidget {
  final Function(Product product, double quantity) onProductSelected;
  final int? partnerId; // ID del partner para obtener su lista de precios

  const ProductSearchPopup({
    super.key,
    required this.onProductSelected,
    this.partnerId,
  });

  @override
  State<ProductSearchPopup> createState() => _ProductSearchPopupState();
}

class _ProductSearchPopupState extends State<ProductSearchPopup> {
  final _searchController = TextEditingController();
  final Map<int, double> _selectedProducts = {}; // productId -> quantity

  @override
  void initState() {
    super.initState();
    // Cargar productos con lista de precios del partner si está disponible
    if (widget.partnerId != null) {
      context.read<ProductBloc>().add(LoadProductsWithPricelist(partnerId: widget.partnerId!));
    } else {
      // Fallback: cargar todos los productos
      context.read<ProductBloc>().add(LoadProducts());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16.0),
      child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seleccionar Productos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Campo de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch();
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _performSearch(),
            ),
            const SizedBox(height: 16),
            
            // Lista de productos
            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  if (state is ProductLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ProductLoaded || state is ProductLoadedWithPricelist) {
                    final products = state is ProductLoaded 
                        ? state.products 
                        : (state as ProductLoadedWithPricelist).products;
                    
                    return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final currentQuantity = _selectedProducts[product.id] ?? 0.0;
                        
                        return ProductAddonWidget(
                          product: product,
                          initialQuantity: currentQuantity,
                          onQuantityChanged: (newQuantity) {
                            setState(() {
                              if (newQuantity > 0) {
                                _selectedProducts[product.id] = newQuantity;
                              } else {
                                _selectedProducts.remove(product.id);
                              }
                            });
                          },
                          onRemove: () {
                            setState(() {
                              _selectedProducts.remove(product.id);
                            });
                          },
                        );
                      },
                    );
                  } else if (state is ProductSearchResult || state is ProductSearchResultWithPricelist) {
                    final products = state is ProductSearchResult 
                        ? state.products 
                        : (state as ProductSearchResultWithPricelist).products;
                    
                    return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final currentQuantity = _selectedProducts[product.id] ?? 0.0;
                        
                        return ProductAddonWidget(
                          product: product,
                          initialQuantity: currentQuantity,
                          onQuantityChanged: (newQuantity) {
                            setState(() {
                              if (newQuantity > 0) {
                                _selectedProducts[product.id] = newQuantity;
                              } else {
                                _selectedProducts.remove(product.id);
                              }
                            });
                          },
                          onRemove: () {
                            setState(() {
                              _selectedProducts.remove(product.id);
                            });
                          },
                        );
                      },
                    );
                  } else if (state is ProductEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (state is ProductError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${state.message}',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(child: Text('Iniciando...'));
                },
              ),
            ),
            
            // Botón de confirmar
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedProducts.isNotEmpty ? _confirmSelection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Confirmar (${_selectedProducts.length} productos)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
    );
  }

  void _performSearch() {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      // Recargar con la misma configuración (con o sin pricelist)
      if (widget.partnerId != null) {
        context.read<ProductBloc>().add(LoadProductsWithPricelist(partnerId: widget.partnerId!));
      } else {
        context.read<ProductBloc>().add(LoadProducts());
      }
    } else {
      // Buscar con pricelist si está disponible
      if (widget.partnerId != null) {
        context.read<ProductBloc>().add(SearchProductsWithPricelist(
          searchTerm: searchTerm, 
          partnerId: widget.partnerId!
        ));
      } else {
        context.read<ProductBloc>().add(SearchProducts(searchTerm: searchTerm));
      }
    }
  }

  void _confirmSelection() {
    // Obtener todos los productos seleccionados
    final products = context.read<ProductBloc>().state;
    List<Product> productList = [];
    
    if (products is ProductLoaded) {
      productList = products.products;
    } else if (products is ProductLoadedWithPricelist) {
      productList = products.products;
    } else if (products is ProductSearchResult) {
      productList = products.products;
    } else if (products is ProductSearchResultWithPricelist) {
      productList = products.products;
    }
    
    if (productList.isNotEmpty) {
      for (final entry in _selectedProducts.entries) {
        final product = productList.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => throw Exception('Product not found'),
        );
        widget.onProductSelected(product, entry.value);
      }
    }
    Navigator.of(context).pop();
  }
}

