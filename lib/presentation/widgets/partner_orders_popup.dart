import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sale_order_model.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../pages/sale_order_view_page.dart';

/// Popup para mostrar el historial de pedidos de un partner
class PartnerOrdersPopup extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  
  const PartnerOrdersPopup({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  State<PartnerOrdersPopup> createState() => _PartnerOrdersPopupState();
}

class _PartnerOrdersPopupState extends State<PartnerOrdersPopup> {
  @override
  void initState() {
    super.initState();
    // Cargar las órdenes del partner al inicializar
    context.read<SaleOrderBloc>().add(LoadSaleOrdersByPartner(partnerId: widget.partnerId));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Historial de Pedidos\n${widget.partnerName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lista de órdenes
            Expanded(
              child: BlocBuilder<SaleOrderBloc, SaleOrderState>(
                builder: (context, state) {
                  if (state is SaleOrderLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is SaleOrdersLoadedByPartner && 
                      state.partnerId == widget.partnerId) {
                    if (state.orders.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildOrdersList(state.orders);
                  }
                  
                  if (state is SaleOrderError) {
                    return _buildErrorState(state.message);
                  }
                  
                  return const Center(
                    child: Text('Cargando órdenes...'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No hay pedidos para este cliente',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error al cargar las órdenes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<SaleOrderBloc>().add(LoadSaleOrdersByPartner(partnerId: widget.partnerId));
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<SaleOrder> orders) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStateColor(order.state),
              child: Text(
                order.name.split(' ').last, // Última parte del nombre de la orden
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(order.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fecha: ${_formatDate(order.dateOrder)}'),
                Text('Total: \$${order.amountTotal.toStringAsFixed(2)}'),
              ],
            ),
            trailing: _buildStateChip(order.state),
            onTap: () => _openOrderDetails(order),
          ),
        );
      },
    );
  }

  Widget _buildStateChip(String state) {
    Color color;
    String label;
    
    switch (state) {
      case 'draft':
        color = Colors.orange;
        label = 'Borrador';
        break;
      case 'sale':
        color = Colors.blue;
        label = 'Confirmada';
        break;
      case 'done':
        color = Colors.green;
        label = 'Entregada';
        break;
      case 'cancel':
        color = Colors.red;
        label = 'Cancelada';
        break;
      default:
        color = Colors.grey;
        label = state;
    }
    
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.orange;
      case 'sale':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _openOrderDetails(SaleOrder order) {
    Navigator.of(context).pop(); // Cerrar el popup
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SaleOrderViewPage(orderId: order.id),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
