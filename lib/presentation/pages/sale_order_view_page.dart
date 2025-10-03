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
  bool _auditInfoExpanded = false; // Estado para auditoría desplegable

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
            const SizedBox(height: 8),
            _buildExpandableAuditInfo(),
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

  /// Construye widget de información de auditoría desplegable
  Widget _buildExpandableAuditInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón desplegable
          InkWell(
            onTap: () {
              setState(() {
                _auditInfoExpanded = !_auditInfoExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _auditInfoExpanded ? Icons.info : Icons.info_outline,
                    size: 16,
                    color: _auditInfoExpanded ? Colors.blue : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+ info',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _auditInfoExpanded ? Colors.blue : Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _auditInfoExpanded ? 'Ocultar' : 'Ver detalles',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _auditInfoExpanded 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Contenido desplegable
          if (_auditInfoExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildAuditContent(),
            ),
          ],
        ],
      ),
    );
  }

  /// Construye el contenido de auditoría
  Widget _buildAuditContent() {
    return Column(
      children: [
        // Usuario responsable de la operación
        if (_currentOrder!.userName != null) ...[
          _buildAuditRow(
            icon: Icons.person,
            label: 'Usuario Responsable:',
            value: _currentOrder!.userName!,
          ),
          const SizedBox(height: 6),
        ],
        
        // Información de creación
        _buildAuditRow(
          icon: Icons.add_circle_outline,
          label: 'Creado por:',
          value: _currentOrder!.createUserName ?? 'Usuario ${_currentOrder!.createUid}',
          dateColor: Colors.green,
          timestamp: _currentOrder!.createDate,
        ),
        const SizedBox(height: 6),
        
        // Información de última modificación
        if (_currentOrder!.writeUid != null && _currentOrder!.writeDate != null) ...[
          _buildAuditRow(
            icon: Icons.edit_outlined,
            label: 'Última modificación:',
            value: _currentOrder!.writeUserName ?? 'Usuario ${_currentOrder!.writeUid}',
            dateColor: Colors.orange,
            timestamp: _currentOrder!.writeDate!,
          ),
          const SizedBox(height: 6),
        ],
        
        // Estado actual
        _buildAuditRow(
          icon: Icons.info_outline,
          label: 'Estado actual:',
          value: _getStateDescription(_currentOrder!.state),
          dateColor: _getStateColor(_currentOrder!.state),
        ),
      ],
    );
  }

  /// Construye una fila de información de auditoría
  Widget _buildAuditRow({
    required IconData icon,
    required String label,
    required String value,
    Color? dateColor,
    String? timestamp,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: dateColor ?? Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  TextSpan(text: '\nActualizado: '),
                  TextSpan(
                    text: _formatDateTime(timestamp),
                    style: TextStyle(
                      color: dateColor ?? Colors.grey[700],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Obtiene descripción del estado en español
  String _getStateDescription(String state) {
    switch (state) {
      case 'draft':
        return 'Borrador';
      case 'sent':
        return 'Cotización Enviada';
      case 'sale':
        return 'Confirmada';
      case 'done':
        return 'Entregada';
      case 'cancel':
        return 'Cancelada';
      default:
        return state.toUpperCase();
    }
  }

  /// Obtiene color según el estado
  Color _getStateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'sale':
        return Colors.green;
      case 'done':
        return Colors.green[700]!;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Formatea fecha y hora para auditoría
  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
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
