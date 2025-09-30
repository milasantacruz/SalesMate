import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../core/di/injection_container.dart';
import '../bloc/partner_bloc.dart';
import '../bloc/partner_state.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../widgets/product_addon_widget.dart';
import '../widgets/product_search_popup.dart';
import '../widgets/order_totals_widget.dart';
import '../../data/models/create_sale_order_request.dart';
import '../../data/models/sale_order_line_model.dart';
import '../../data/models/partner_model.dart';
import '../../data/models/product_model.dart';

/// Página para crear un nuevo pedido de venta
class NuevoPedidoPage extends StatefulWidget {
  final Partner? selectedPartner;
  
  const NuevoPedidoPage({super.key, this.selectedPartner});

  @override
  State<NuevoPedidoPage> createState() => _NuevoPedidoPageState();
}

class _NuevoPedidoPageState extends State<NuevoPedidoPage> {
  final _formKey = GlobalKey<FormState>();
  final _partnerSearchController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  
  Partner? _selectedPartner;
  List<SaleOrderLine> _orderLines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si se pasó un partner seleccionado, configurarlo
    if (widget.selectedPartner != null) {
      _selectedPartner = widget.selectedPartner!;
      _partnerSearchController.text = _selectedPartner!.name;
    }
  }

  @override
  void dispose() {
    _partnerSearchController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SaleOrderBloc, SaleOrderState>(
      listener: (context, state) {
        if (state is SaleOrderCreating) {
          setState(() => _isLoading = true);
        } else if (state is SaleOrderCreated) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pedido creado exitosamente (ID: ${state.orderId})')),
          );
          Navigator.of(context).pop();
        } else if (state is SaleOrderError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo Pedido'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showOrderInfo,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderNumberField(),
                      const SizedBox(height: 16),
                      _buildPartnerSelection(),
                      const SizedBox(height: 16),
                      _buildDeliveryAddressField(),
                      const SizedBox(height: 16),
                      _buildOrderLinesSection(),
                      const SizedBox(height: 16),
                       OrderTotalsWidget(
                         partnerId: _selectedPartner?.id ?? 0,
                         orderLines: List.from(_orderLines), // Crear una copia de la lista
                       ),
                    ],
                  ),
                ),
              ),
              _buildBottomActionMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderNumberField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Número de Pedido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Se generará automáticamente',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente *',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            BlocBuilder<PartnerBloc, PartnerState>(
              builder: (context, state) {
                if (state is PartnerLoaded) {
                  return DropdownButtonFormField<Partner>(
                    value: _selectedPartner,
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar cliente',
                      border: OutlineInputBorder(),
                    ),
                    items: state.partners.map((partner) {
                      return DropdownMenuItem<Partner>(
                        value: partner,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              partner.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (partner.email != null)
                              Text(
                                partner.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Partner? partner) {
                      setState(() {
                        _selectedPartner = partner;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Debe seleccionar un cliente';
                      }
                      return null;
                    },
                  );
                } else if (state is PartnerLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return const Text('Error cargando clientes');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dirección de Despacho',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _deliveryAddressController,
              decoration: const InputDecoration(
                hintText: 'Ingrese la dirección de entrega',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderLinesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showProductSearch,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_orderLines.isEmpty)
              Container(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay productos agregados',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Haga clic en "Agregar" para seleccionar productos',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orderLines.length,
                itemBuilder: (context, index) {
                  final line = _orderLines[index];
                  return ProductAddonWidget(
                    product: Product(
                      id: line.productId,
                      name: line.productName,
                      defaultCode: line.productCode,
                      type: 'product',
                      listPrice: line.priceUnit,
                      uomId: null,
                      uomName: null,
                      taxesIds: line.taxesIds,
                    ),
                    initialQuantity: line.quantity,
                    onQuantityChanged: (newQuantity) {
                      setState(() {
                        _orderLines[index] = line.copyWith(quantity: newQuantity);
                      });
                    },
                    onRemove: () {
                      setState(() {
                        _orderLines.removeAt(index);
                      });
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomActionMenu() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              highlightColor: const Color.fromARGB(255, 91, 233, 30),
              splashColor: Colors.pink,
              focusColor: const Color.fromARGB(255, 233, 182, 30),
              hoverColor: const Color.fromARGB(255, 40, 30, 233),
              onTap: _showProductSearch,
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size:28),
                  Text('Productos'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _isLoading ? null : _saveDraft,
              child: Column(
                children: [
                  Icon(Icons.save, size:28),
                  Text('Guardar'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _isLoading ? null : _sendOrder,
              child: Column(
                children: [
                  Icon(Icons.send, size:28),
                  Text('Enviar'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),
          
          /*Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveDraft,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendOrder,
              icon: const Icon(Icons.send),
              label: const Text('Enviar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),*/
        ],
      ),
    );
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
            partnerId: _selectedPartner?.id,
            onProductSelected: (product, quantity) {
              // Verificar si el producto ya existe
              final existingIndex = _orderLines.indexWhere(
                (line) => line.productId == product.id,
              );
              
              if (existingIndex != -1) {
                // Actualizar cantidad existente
                print('🔄 NUEVO_PEDIDO: Updating existing product at index $existingIndex');
                setState(() {
                  _orderLines[existingIndex] = _orderLines[existingIndex].copyWith(
                    quantity: _orderLines[existingIndex].quantity + quantity,
                  );
                });
                print('🔄 NUEVO_PEDIDO: Updated orderLines.length: ${_orderLines.length}');
              } else {
                // Agregar nuevo producto
                print('🔄 NUEVO_PEDIDO: Adding new product: ${product.name}');
                setState(() {
                  _orderLines.add(SaleOrderLine(
                    productId: product.id,
                    productName: product.name,
                    productCode: product.defaultCode,
                    quantity: quantity,
                    priceUnit: product.listPrice,
                    priceSubtotal: product.listPrice * quantity,
                    taxesIds: product.taxesIds,
                  ));
                });
                print('🔄 NUEVO_PEDIDO: Added orderLines.length: ${_orderLines.length}');
              }
            },
          ),
        ),
      ),
    );
  }

  void _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedDate =
        DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    
    // Obtenemos el ID del usuario de la sesión actual
    final currentUserId = getIt<OdooSession>().userId;

    final request = CreateSaleOrderRequest(
      partnerId: _selectedPartner!.id,
      partnerName: _selectedPartner!.name,
      partnerDocument: _selectedPartner!.email,
      deliveryAddress: _deliveryAddressController.text,
      dateOrder: formattedDate,
      userId: currentUserId,
      orderLines: _orderLines,
      state: 'draft',
    );

    context
        .read<SaleOrderBloc>()
        .add(CreateSaleOrder(orderData: request.toJson()));
  }

  void _sendOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedDate =
        DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');

    // Obtenemos el ID del usuario de la sesión actual
    final currentUserId = getIt<OdooSession>().userId;

    final request = CreateSaleOrderRequest(
      partnerId: _selectedPartner!.id,
      partnerName: _selectedPartner!.name,
      partnerDocument: _selectedPartner!.email,
      deliveryAddress: _deliveryAddressController.text,
      dateOrder: formattedDate,
      userId: currentUserId,
      orderLines: _orderLines,
      state: 'sent',
    );

    context
        .read<SaleOrderBloc>()
        .add(CreateSaleOrder(orderData: request.toJson()));
  }

  void _showOrderInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${_selectedPartner?.name ?? 'No seleccionado'}'),
            Text('Productos: ${_orderLines.length}'),
            Text('Total: \$${_orderLines.fold(0.0, (sum, line) => sum + line.subtotal).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

