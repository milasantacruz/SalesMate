import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sale_order_model.dart';
import '../../data/models/sale_order_line_model.dart';
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
                onPressed: _sendQuotation,
                tooltip: 'Enviar cotización',
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _confirmOrder,
                tooltip: 'Confirmar orden',
              ),
            ],
            if (_currentOrder!.state == 'sent') ...[
              IconButton(
                icon: const Icon(Icons.check),
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
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Ver detalles',
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(state.message),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
          } else if (state is SaleOrderSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cotización enviada exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
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
    //TODO: Implementar la lógica para guardar los cambios
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

  void _sendQuotation() {
    if (_currentOrder == null) return;
    
    // Validar que la orden pueda ser enviada
    String? validationError = _validateOrderForSending();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Cotización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Enviar esta cotización al cliente?'),
            const SizedBox(height: 16),
            Text(
              'Orden: ${_currentOrder!.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_currentOrder!.partnerName != null)
              Text('Cliente: ${_currentOrder!.partnerName}'),
            Text('Productos: ${_orderLines.length}'),
            Text('Total: \$${_currentOrder!.amountTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text(
              'Se enviará por email al cliente.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SaleOrderBloc>().add(
                SendQuotation(orderId: _currentOrder!.id),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _confirmOrder() {
    if (_currentOrder == null) return;
    
    // Validar que la orden pueda ser confirmada
    String? validationError = _validateOrderForConfirmation();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Orden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que quieres confirmar esta orden?'),
            const SizedBox(height: 16),
            Text(
              'Orden: ${_currentOrder!.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_currentOrder!.partnerName != null)
              Text('Cliente: ${_currentOrder!.partnerName}'),
            Text('Productos: ${_orderLines.length}'),
            Text('Total: \$${_currentOrder!.amountTotal.toStringAsFixed(2)}'),
          ],
        ),
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

  String? _validateOrderForConfirmation() {
    if (_currentOrder == null) {
      return 'Orden no encontrada';
    }
    
    if (_currentOrder!.state != 'draft') {
      return 'Solo se pueden confirmar órdenes en estado borrador';
    }
    
    if (_currentOrder!.partnerId == null) {
      return 'La orden debe tener un cliente asignado';
    }
    
    if (_orderLines.isEmpty) {
      return 'La orden debe tener al menos un producto';
    }
    
    // Verificar que todas las líneas tengan cantidad > 0
    for (int i = 0; i < _orderLines.length; i++) {
      if (_orderLines[i].quantity <= 0) {
        return 'El producto "${_orderLines[i].productName}" debe tener una cantidad mayor a 0';
      }
    }
    
    return null; // Sin errores
  }

  String? _validateOrderForSending() {
    if (_currentOrder == null) {
      return 'Orden no encontrada';
    }
    
    if (_currentOrder!.state != 'draft') {
      return 'Solo se pueden enviar cotizaciones en estado borrador';
    }
    
    if (_currentOrder!.partnerId == null) {
      return 'La orden debe tener un cliente asignado';
    }
    
    if (_orderLines.isEmpty) {
      return 'La orden debe tener al menos un producto';
    }
    
    // Verificar que todas las líneas tengan cantidad > 0
    for (int i = 0; i < _orderLines.length; i++) {
      if (_orderLines[i].quantity <= 0) {
        return 'El producto "${_orderLines[i].productName}" debe tener una cantidad mayor a 0';
      }
    }
    
    return null; // Sin errores
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
