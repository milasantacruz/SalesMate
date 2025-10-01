import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sale_order_model.dart';
import '../../data/models/sale_order_line_model.dart';
import '../../data/models/partner_model.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../widgets/order_totals_widget.dart';

/// Página para visualizar y editar una orden de venta existente
class SaleOrderViewPage extends StatefulWidget {
  final int orderId;
  
  const SaleOrderViewPage({
    super.key,
    required this.orderId,
  });

  @override
  State<SaleOrderViewPage> createState() => _SaleOrderViewPageState();
}

class _SaleOrderViewPageState extends State<SaleOrderViewPage> {
  SaleOrder? _currentOrder;
  List<SaleOrderLine> _orderLines = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Cargar la orden al inicializar
    context.read<SaleOrderBloc>().add(LoadSaleOrderById(orderId: widget.orderId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentOrder?.name ?? 'Cargando...'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentOrder != null) ...[
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isEditing ? _saveOrder : _toggleEdit,
              tooltip: _isEditing ? 'Guardar cambios' : 'Editar orden',
            ),
            if (_currentOrder!.state == 'draft') ...[
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _confirmOrder,
                tooltip: 'Confirmar orden',
              ),
            ],
          ],
        ],
      ),
      body: BlocConsumer<SaleOrderBloc, SaleOrderState>(
        listener: (context, state) {
          if (state is SaleOrderLoadedById) {
            setState(() {
              _currentOrder = state.order;
              _orderLines = state.order.orderLines;
            });
          } else if (state is SaleOrderError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is SaleOrderUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Orden actualizada exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {
              _isEditing = false;
            });
          }
        },
        builder: (context, state) {
          if (state is SaleOrderLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is SaleOrderError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar la orden',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SaleOrderBloc>().add(LoadSaleOrderById(orderId: widget.orderId));
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          
          if (_currentOrder == null) {
            return const Center(
              child: Text('No se pudo cargar la orden'),
            );
          }
          
          return _buildOrderContent();
        },
      ),
    );
  }

  Widget _buildOrderContent() {
    return Column(
      children: [
        // Información de la orden
        _buildOrderInfo(),
        
        // Líneas de la orden
        Expanded(
          child: _buildOrderLines(),
        ),
        
        // Totales
        if (_orderLines.isNotEmpty && _currentOrder?.partnerId != null)
          OrderTotalsWidget(
            partnerId: _currentOrder!.partnerId!,
            orderLines: _orderLines,
          ),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orden: ${_currentOrder!.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _buildStateChip(_currentOrder!.state),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentOrder!.partnerName != null)
              Text('Cliente: ${_currentOrder!.partnerName}'),
            Text('Fecha: ${_formatDate(_currentOrder!.dateOrder)}'),
            Text('Total: \$${_currentOrder!.amountTotal.toStringAsFixed(2)}'),
          ],
        ),
      ),
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
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      side: BorderSide.none,
    );
  }

  Widget _buildOrderLines() {
    if (_orderLines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay productos en esta orden',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orderLines.length,
      itemBuilder: (context, index) {
        final line = _orderLines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${line.quantity.toInt()}'),
            ),
            title: Text(line.productName),
            subtitle: Text('Precio: \$${line.priceUnit.toStringAsFixed(2)}'),
            trailing: _isEditing
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeOrderLine(index),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveOrder() {
    if (_currentOrder == null) return;
    
    // Aquí implementarías la lógica para guardar los cambios
    // Por ahora solo cambiamos el estado de edición
    setState(() {
      _isEditing = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cambios guardados'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmOrder() {
    if (_currentOrder == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Orden'),
        content: const Text('¿Estás seguro de que quieres confirmar esta orden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SaleOrderBloc>().add(
                UpdateSaleOrder(
                  orderId: _currentOrder!.id,
                  orderData: {'state': 'sale'},
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _removeOrderLine(int index) {
    setState(() {
      _orderLines.removeAt(index);
    });
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
