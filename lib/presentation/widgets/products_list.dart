import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/product/product_state.dart';
import '../bloc/product/product_event.dart';

/// Widget para mostrar la lista de Productos con filtros
class ProductsList extends StatefulWidget {
  const ProductsList({super.key});

  @override
  State<ProductsList> createState() => _ProductsListState();
}

class _ProductsListState extends State<ProductsList> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _dispatchFilterEvent();
    });
  }

  void _onTypeSelected(String? type) {
    setState(() {
      _selectedType = type;
    });
    _dispatchFilterEvent();
  }

  void _dispatchFilterEvent() {
    context.read<ProductBloc>().add(SearchAndFilterProducts(
          searchTerm: _searchController.text,
          type: _selectedType,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterControls(),
        Expanded(
          child: BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              if (state is ProductLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ProductLoaded) {
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ProductBloc>().add(RefreshProducts());
                  },
                  child: ListView.builder(
                    itemCount: state.products.length,
                    itemBuilder: (context, index) {
                      final product = state.products[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ListTile(
                          title: Text(product.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Text('Tipo: ${_getTypeDisplayName(product)}'),
                              if (product.uomName != null)
                                Text('UOM: ${product.uomName}'),
                              if (product.taxesIds.isNotEmpty)
                                Text('Impuestos: ${product.taxesIds.length}'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${product.listPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              _buildProductTypeChip(product),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              } else if (state is ProductEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
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
                          fontSize: 16,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<ProductBloc>().add(LoadProducts());
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: Text('Iniciando...'));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por código o nombre',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip(label: 'Todos', type: null),
                _buildTypeChip(label: 'Productos', type: 'product'),
                _buildTypeChip(label: 'Servicios', type: 'service'),
                _buildTypeChip(label: 'Consumibles', type: 'consu'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTypeChip({required String label, required String? type}) {
    final bool isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onTypeSelected(type),
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildProductTypeChip(product) {
    return Chip(
      label: Text(_getTypeDisplayName(product)),
      backgroundColor: _getTypeColor(product),
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  String _getTypeDisplayName(product) {
    // Nueva lógica basada en type + is_storable
    if (product.type == 'service' && product.isStorable == false) return 'Servicio';
    if (product.type == 'consu' && product.isStorable == true) return 'Producto';
    if (product.type == 'consu' && product.isStorable == false) return 'Consumible';
    return product.type;
  }

  Color _getTypeColor(product) {
    if (product.type == 'service' && product.isStorable == false) return Colors.green.shade100;
    if (product.type == 'consu' && product.isStorable == true) return Colors.blue.shade100;
    if (product.type == 'consu' && product.isStorable == false) return Colors.orange.shade100;
    return Colors.grey.shade200;
  }
}
