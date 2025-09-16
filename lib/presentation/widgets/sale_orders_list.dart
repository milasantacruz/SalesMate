import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../bloc/sale_order/sale_order_event.dart';

/// Widget para mostrar la lista de Órdenes de Venta con filtros
class SaleOrdersList extends StatefulWidget {
  const SaleOrdersList({super.key});

  @override
  State<SaleOrdersList> createState() => _SaleOrdersListState();
}

class _SaleOrdersListState extends State<SaleOrdersList> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedState;

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

  void _onStateSelected(String? state) {
    setState(() {
      _selectedState = state;
    });
    _dispatchFilterEvent();
  }

  void _dispatchFilterEvent() {
    context.read<SaleOrderBloc>().add(SearchAndFilterSaleOrders(
          searchTerm: _searchController.text,
          state: _selectedState,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterControls(),
        Expanded(
          child: BlocBuilder<SaleOrderBloc, SaleOrderState>(
            builder: (context, state) {
              if (state is SaleOrderLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SaleOrderLoaded) {
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<SaleOrderBloc>().add(RefreshSaleOrders());
                  },
                  child: ListView.builder(
                    itemCount: state.saleOrders.length,
                    itemBuilder: (context, index) {
                      final order = state.saleOrders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ListTile(
                          title: Text(order.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Cliente: ${order.partnerName ?? 'N/A'}\nFecha: ${order.dateOrder}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${order.amountTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(order.state),
                                backgroundColor: _getStateColor(order.state),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              } else if (state is SaleOrderEmpty) {
                return Center(child: Text(state.message));
              } else if (state is SaleOrderError) {
                return Center(child: Text('Error: ${state.message}'));
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
                labelText: 'Buscar por N° de pedido o cliente',
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
                _buildStateChip(label: 'Todos', state: null),
                _buildStateChip(label: 'Borrador', state: 'draft'),
                _buildStateChip(label: 'Enviado', state: 'sent'),
                _buildStateChip(label: 'Confirmado', state: 'sale'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStateChip({required String label, required String? state}) {
    final bool isSelected = _selectedState == state;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onStateSelected(state),
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'sale':
      case 'done':
        return Colors.green.shade100;
      case 'draft':
      case 'sent':
        return Colors.blue.shade100;
      case 'cancel':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
