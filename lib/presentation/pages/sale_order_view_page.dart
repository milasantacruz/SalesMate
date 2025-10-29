import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sale_order_model.dart';
import '../../data/models/sale_order_line_model.dart';
import '../../data/models/partner_model.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../bloc/product/product_bloc.dart';
import '../widgets/order_totals_widget.dart';
import '../widgets/product_search_popup.dart';
import '../widgets/create_shipping_address_dialog.dart';
import '../../core/di/injection_container.dart';
import '../../data/repositories/sale_order_repository.dart';
import '../../data/repositories/shipping_address_repository.dart';

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
  List<SaleOrderLine> _originalOrderLines = []; // Copia de las líneas originales
  bool _isEditing = false;
  bool _auditInfoExpanded = false; // Estado para auditoría desplegable
  
  // Variables para edición
  Partner? _selectedShippingAddress;
  List<Partner> _deliveryAddresses = [];
  bool _isLoadingAddresses = false;
  final Map<int, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    // Cargar la orden al inicializar
    context.read<SaleOrderBloc>().add(LoadSaleOrderById(orderId: widget.orderId));
  }

  @override
  void dispose() {
    // Limpiar controladores de cantidad
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              _orderLines = List<SaleOrderLine>.from(state.order.orderLines);
              _originalOrderLines = List<SaleOrderLine>.from(state.order.orderLines); // Copia profunda
            });
            // Cargar direcciones de despacho del cliente
            if (_currentOrder?.partnerId != null) {
              _loadDeliveryAddresses(_currentOrder!.partnerId!);
            }
            // Inicializar controladores de cantidad
            _initializeQuantityControllers();
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // Información de la orden
          _buildOrderInfo(),
          
          // Líneas de la orden
          _buildOrderLines(),
          
          // Totales
          if (_orderLines.isNotEmpty && _currentOrder?.partnerId != null)
            OrderTotalsWidget(
              partnerId: _currentOrder!.partnerId!,
              orderLines: _orderLines,
              isEditing: _isEditing,
            ),
        ],
      ),
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
            const SizedBox(height: 16),
            
            // Sección de dirección de despacho
            _buildShippingAddressSection(),
            
            const SizedBox(height: 8),
            _buildExpandableAuditInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dirección de Despacho',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_isEditing)
              TextButton.icon(
                onPressed: _showAddressSelector,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Cambiar'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (_isLoadingAddresses)
          const Center(child: CircularProgressIndicator())
        else
          _buildAddressDisplay(),
      ],
    );
  }

  Widget _buildAddressDisplay() {
    if (_selectedShippingAddress != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedShippingAddress!.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedShippingAddress!.singleLineAddress,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_selectedShippingAddress!.phone != null && _selectedShippingAddress!.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _selectedShippingAddress!.phone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else if (_currentOrder?.partnerShippingId != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dirección del cliente (ID: ${_currentOrder!.partnerShippingId})',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, size: 16, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isEditing ? 'Sin dirección de despacho - Selecciona una' : 'Sin dirección de despacho',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange[800],
                ),
              ),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _showAddressSelector,
                child: const Text('Seleccionar'),
              ),
          ],
        ),
      );
    }
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con botón para agregar productos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_isEditing)
                  ElevatedButton.icon(
                    onPressed: _showProductSearch,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lista de productos
            if (_orderLines.isEmpty)
              Container(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No hay productos en esta orden',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showProductSearch,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Primer Producto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _orderLines.asMap().entries.map((entry) {
                  final index = entry.key;
                  final line = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildOrderLineCard(line, index),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderLineCard(SaleOrderLine line, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Ícono de cantidad
                CircleAvatar(
                  backgroundColor: _isEditing ? Colors.blue[100] : Colors.grey[200],
                  child: Text(
                    '${line.quantity.toInt()}',
                    style: TextStyle(
                      color: _isEditing ? Colors.blue[800] : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Información del producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Precio: \$${line.priceUnit.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (line.priceSubtotal > 0)
                        Text(
                          'Subtotal: \$${line.priceSubtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Botones de acción
                if (_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Campo de cantidad editable
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _quantityControllers[line.productId],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (value) {
                            final quantity = double.tryParse(value) ?? 0;
                            print('📝 TEXTFIELD CHANGED: productId=${line.productId}, oldQuantity=${line.quantity}, newQuantity=$quantity');
                            if (quantity != line.quantity) {
                              print('📝 UPDATING LINE: ${line.productId} quantity from ${line.quantity} to $quantity');
                              setState(() {
                                _orderLines[index] = line.copyWith(
                                  quantity: quantity,
                                  priceSubtotal: line.priceUnit * quantity,
                                );
                              });
                              print('📝 LINE UPDATED: ${_orderLines[index].quantity}');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón eliminar
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeOrderLine(index),
                        tooltip: 'Eliminar producto',
                      ),
                    ],
                  )
                else
                  // Mostrar cantidad en modo lectura
                  Text(
                    'Cantidad: ${line.quantity.toInt()}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveOrder() async {
    if (_currentOrder == null) return;
    
    print('💾 GUARDANDO ORDEN: ${_currentOrder!.id}');
    print('💾 LÍNEAS ACTUALES: ${_orderLines.length}');
    
    // Obtener líneas originales de la orden (copia guardada al cargar)
    final originalLines = _originalOrderLines;
    print('💾 LÍNEAS ORIGINALES: ${originalLines.length}');
    for (int i = 0; i < originalLines.length; i++) {
      final line = originalLines[i];
      print('💾 LÍNEA ORIGINAL $i: ID=${line.id}, productId=${line.productId}, productName=${line.productName}, quantity=${line.quantity}');
    }
    
    try {
      // 1. ELIMINAR líneas que ya no están en _orderLines
      for (final originalLine in originalLines) {
        if (originalLine.id == null) {
          print('⚠️ SALE_ORDER_VIEW: Ignorando línea original sin ID válido');
          continue;
        }
        
        final stillExists = _orderLines.any((currentLine) => 
            currentLine.id != null && currentLine.id == originalLine.id);
        
        if (!stillExists) {
          print('💾 ELIMINANDO línea ID: ${originalLine.id}');
          // Llamar directamente a sale.order.line.unlink
          await _deleteOrderLine(originalLine.id!);
        }
      }
      
      // 2. PROCESAR líneas actuales
      print('💾 LÍNEAS ACTUALES: ${_orderLines.length}');
      for (int i = 0; i < _orderLines.length; i++) {
        final line = _orderLines[i];
        print('💾 LÍNEA ACTUAL $i: ID=${line.id}, productId=${line.productId}, productName=${line.productName}, quantity=${line.quantity}');
      }
      
      for (final line in _orderLines) {
        if (line.id == null) {
          // Nueva línea - CREAR directamente
          print('💾 CREANDO nueva línea para producto: ${line.productId}');
          await _createOrderLine(line);
        } else {
          // Línea existente - verificar si necesita actualización
          final originalLine = originalLines.firstWhere(
            (ol) => ol.id != null && ol.id == line.id,
            orElse: () => SaleOrderLine(
              id: null,
              productId: 0,
              productName: '',
              quantity: 0,
              priceUnit: 0,
              priceSubtotal: 0,
              taxesIds: [],
            ),
          );
          
          // Verificar si hay cambios
          final hasChanges = originalLine.quantity != line.quantity ||
                            originalLine.priceUnit != line.priceUnit;
          
          print('🔍 COMPARACIÓN línea ID: ${line.id}');
          print('🔍   Original quantity: ${originalLine.quantity} vs Actual: ${line.quantity}');
          print('🔍   Original priceUnit: ${originalLine.priceUnit} vs Actual: ${line.priceUnit}');
          print('🔍   HasChanges: $hasChanges');
          
          if (hasChanges) {
            print('💾 ACTUALIZANDO línea ID: ${line.id}');
            await _updateOrderLine(line.id!, line);
          } else {
            print('💾 SIN CAMBIOS en línea ID: ${line.id}');
          }
        }
      }
      
      // 3. ACTUALIZAR dirección de despacho si es necesario
      if (_selectedShippingAddress != null) {
        print('💾 ACTUALIZANDO dirección de despacho: ${_selectedShippingAddress!.id}');
        await _updateOrderShippingAddress(_selectedShippingAddress!.id);
      }
      
      // Recargar la orden para obtener los datos actualizados
      print('🔄 Recargando orden después de actualizaciones...');
      context.read<SaleOrderBloc>().add(LoadSaleOrderById(orderId: _currentOrder!.id));
      
      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orden actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('❌ Error actualizando orden: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar orden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Crea una nueva línea de orden directamente usando sale.order.line.create
  Future<void> _createOrderLine(SaleOrderLine line) async {
    try {
      final saleOrderRepo = getIt<SaleOrderRepository>();
      final result = await saleOrderRepo.createOrderLine(
        orderId: _currentOrder!.id,
        productId: line.productId,
        quantity: line.quantity,
        priceUnit: line.priceUnit,
      );
      print('✅ Línea creada exitosamente: $result');
    } catch (e) {
      print('❌ Error creando línea: $e');
      rethrow;
    }
  }

  /// Actualiza una línea de orden existente usando sale.order.line.write
  Future<void> _updateOrderLine(int lineId, SaleOrderLine line) async {
    try {
      final saleOrderRepo = getIt<SaleOrderRepository>();
      await saleOrderRepo.updateOrderLine(
        lineId: lineId,
        quantity: line.quantity,
        priceUnit: line.priceUnit,
      );
      print('✅ Línea actualizada exitosamente: $lineId');
    } catch (e) {
      print('❌ Error actualizando línea: $e');
      rethrow;
    }
  }

  /// Elimina una línea de orden usando sale.order.line.unlink
  Future<void> _deleteOrderLine(int lineId) async {
    try {
      final saleOrderRepo = getIt<SaleOrderRepository>();
      await saleOrderRepo.deleteOrderLine(lineId);
      print('✅ Línea eliminada exitosamente: $lineId');
    } catch (e) {
      print('❌ Error eliminando línea: $e');
      rethrow;
    }
  }

  /// Actualiza la dirección de despacho de la orden
  Future<void> _updateOrderShippingAddress(int addressId) async {
    try {
      final saleOrderRepo = getIt<SaleOrderRepository>();
      await saleOrderRepo.updateOrder(
        _currentOrder!.id,
        {'partner_shipping_id': addressId},
      );
      print('✅ Dirección de despacho actualizada: $addressId');
    } catch (e) {
      print('❌ Error actualizando dirección de despacho: $e');
      rethrow;
    }
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<ProductBloc>()),
        ],
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ProductSearchPopup(
            partnerId: _currentOrder?.partnerId,
            onProductSelected: (product, quantity) {
              // Verificar si el producto ya existe
              final existingIndex = _orderLines.indexWhere(
                (line) => line.productId == product.id,
              );
              
              if (existingIndex != -1) {
                // Actualizar cantidad existente
                setState(() {
                  _orderLines[existingIndex] = _orderLines[existingIndex].copyWith(
                    quantity: _orderLines[existingIndex].quantity + quantity,
                  );
                });
              } else {
                // Agregar nuevo producto (con id = null para indicar que es nueva)
                setState(() {
                  _orderLines.add(SaleOrderLine(
                    id: null, // null indica que es una línea nueva
                    productId: product.id,
                    productName: product.name,
                    productCode: product.defaultCode,
                    quantity: quantity,
                    priceUnit: product.listPrice,
                    priceSubtotal: product.listPrice * quantity,
                    taxesIds: product.taxesIds,
                  ));
                });
              }
              _updateQuantityControllers();
            },
          ),
        ),
      ),
    );
  }

  void _showAddressSelector() {
    if (_currentOrder?.partnerId == null) return;

    showModalBottomSheet<Partner?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seleccionar Dirección de Despacho',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Lista de direcciones
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Opción para usar dirección del cliente principal
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.business, color: Colors.blue[800]),
                      ),
                      title: const Text(
                        'Usar dirección del cliente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: _currentOrder?.partnerName != null
                          ? Text(
                              _currentOrder!.partnerName!,
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      trailing: _selectedShippingAddress == null
                          ? Icon(Icons.check_circle, color: Colors.blue[700])
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        setState(() {
                          _selectedShippingAddress = null;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  
                  // Direcciones de despacho existentes
                  ..._deliveryAddresses.map((address) => Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.location_on, color: Colors.green[800]),
                      ),
                      title: Text(
                        address.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        address.singleLineAddress,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _selectedShippingAddress?.id == address.id
                          ? Icon(Icons.check_circle, color: Colors.green[700])
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        setState(() {
                          _selectedShippingAddress = address;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  )),
                  
                  // Botón para crear nueva dirección
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange[50],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100],
                        child: Icon(Icons.add_location, color: Colors.orange[800]),
                      ),
                      title: const Text(
                        'Crear Nueva Dirección',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Agregar una nueva dirección de despacho',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showCreateAddressDialog();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateAddressDialog() async {
    if (_currentOrder?.partnerId == null) return;

    final newAddress = await showModalBottomSheet<Partner>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: CreateShippingAddressDialog(
            parentPartnerId: _currentOrder!.partnerId!,
            scrollController: scrollController,
          ),
        ),
      ),
    );

    if (newAddress != null) {
      // ✅ Recargar direcciones desde cache para incluir la nueva dirección guardada
      if (_currentOrder?.partnerId != null) {
        await _loadDeliveryAddresses(_currentOrder!.partnerId!);
      }
      
      setState(() {
        // Asegurar que la nueva dirección está seleccionada
        _selectedShippingAddress = newAddress;
        // Si no apareció en la lista recargada, agregarla manualmente
        if (!_deliveryAddresses.any((addr) => addr.id == newAddress.id)) {
          _deliveryAddresses.add(newAddress);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dirección "${newAddress.name}" creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
    _updateQuantityControllers();
  }

  /// Carga las direcciones de despacho del cliente seleccionado
  Future<void> _loadDeliveryAddresses(int partnerId) async {
    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final shippingAddressRepo = getIt<ShippingAddressRepository>();
      
      // Primero intentar desde caché offline
      final cachedAddresses = shippingAddressRepo.getCachedShippingAddressesForPartner(partnerId);
      
      if (cachedAddresses.isNotEmpty) {
        print('📍 SALE_ORDER_VIEW: ${cachedAddresses.length} direcciones cargadas desde caché offline');
        if (mounted) {
          setState(() {
            _deliveryAddresses = cachedAddresses;
            _isLoadingAddresses = false;
          });
        }
        return;
      }
      
      // Si no hay caché, intentar desde servidor (solo si hay conexión)
      print('📍 SALE_ORDER_VIEW: No hay caché offline, intentando desde servidor...');
      final addresses = await shippingAddressRepo.getShippingAddressesForPartner(partnerId);
      
      if (mounted) {
        setState(() {
          _deliveryAddresses = addresses;
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando direcciones: $e');
      
      // Fallback: intentar desde caché general si falla la llamada al servidor
      try {
        final shippingAddressRepo = getIt<ShippingAddressRepository>();
        final allCachedAddresses = shippingAddressRepo.getCachedShippingAddresses();
        final partnerAddresses = allCachedAddresses.where((addr) => addr.commercialPartnerId == partnerId).toList();
        
        print('📍 SALE_ORDER_VIEW: Fallback - ${partnerAddresses.length} direcciones desde caché general');
        if (mounted) {
          setState(() {
            _deliveryAddresses = partnerAddresses;
            _isLoadingAddresses = false;
          });
        }
      } catch (cacheError) {
        print('❌ Error también en fallback de caché: $cacheError');
        if (mounted) {
          setState(() {
            _isLoadingAddresses = false;
          });
        }
      }
    }
  }

  /// Inicializa los controladores de cantidad para cada línea de orden
  void _initializeQuantityControllers() {
    // Limpiar controladores existentes
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    _quantityControllers.clear();

    // Crear controladores para cada línea
    for (var line in _orderLines) {
      _quantityControllers[line.productId] = TextEditingController(
        text: line.quantity.toString(),
      );
    }
  }

  /// Actualiza los controladores cuando cambia la lista de líneas
  void _updateQuantityControllers() {
    final currentProductIds = _orderLines.map((line) => line.productId).toSet();
    
    // Eliminar controladores de productos que ya no existen
    _quantityControllers.removeWhere((productId, controller) {
      if (!currentProductIds.contains(productId)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    // Agregar controladores para nuevos productos
    for (var line in _orderLines) {
      if (!_quantityControllers.containsKey(line.productId)) {
        _quantityControllers[line.productId] = TextEditingController(
          text: line.quantity.toString(),
        );
      }
    }
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
