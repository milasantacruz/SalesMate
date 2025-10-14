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
import '../widgets/create_shipping_address_dialog.dart';
import '../../data/models/create_sale_order_request.dart';
import '../../data/models/sale_order_line_model.dart';
import '../../data/models/partner_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/partner_repository.dart';

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
  Partner? _selectedShippingAddress;
  List<Partner> _deliveryAddresses = [];
  bool _isLoadingAddresses = false;
  List<SaleOrderLine> _orderLines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si se pasó un partner seleccionado, configurarlo
    if (widget.selectedPartner != null) {
      _selectedPartner = widget.selectedPartner!;
      _partnerSearchController.text = _selectedPartner!.name;
      // Cargar direcciones de despacho del cliente
      _loadDeliveryAddresses(_selectedPartner!.id);
    }
  }

  @override
  void dispose() {
    _partnerSearchController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  /// Carga las direcciones de despacho del cliente seleccionado
  Future<void> _loadDeliveryAddresses(int partnerId) async {
    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final partnerRepo = getIt<PartnerRepository>();
      final addresses = await partnerRepo.getDeliveryAddresses(partnerId);
      
      if (mounted) {
        setState(() {
          _deliveryAddresses = addresses;
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando direcciones: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
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
                     /* _buildOrderNumberField(),
                      const SizedBox(height: 16),*/
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
                    itemHeight: 90,
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

                            Divider(color: Colors.grey[300],),
                            
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Partner? partner) {
                      setState(() {
                        _selectedPartner = partner;
                        _selectedShippingAddress = null;
                        _deliveryAddresses = [];
                      });
                      // Cargar direcciones de despacho del cliente
                      if (partner != null) {
                        _loadDeliveryAddresses(partner.id);
                      }
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dirección de Despacho',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_selectedPartner != null)
                  TextButton.icon(
                    onPressed: _showCreateAddressDialog,
                    icon: const Icon(Icons.add_location, size: 18),
                    label: const Text('Nueva'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Mostrar mensaje si no hay cliente seleccionado
            if (_selectedPartner == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Primero selecciona un cliente',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            
            // Dropdown de direcciones
            else if (_isLoadingAddresses)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Partner?>(
                    itemHeight: 90,
                    value: _selectedShippingAddress,
                    decoration: InputDecoration(
                      hintText: _deliveryAddresses.isEmpty
                          ? 'Sin direcciones - Crear nueva'
                          : 'Seleccionar dirección de despacho',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_shipping),
                    ),
                    items: [
                      // Opción para usar dirección del cliente principal
                      DropdownMenuItem<Partner?>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.business, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            const Text('Usar dirección del cliente'),
                          ],
                        ),
                      ),
                      
                      // Direcciones de despacho existentes
                      ..._deliveryAddresses.map((address) => 
                        DropdownMenuItem<Partner?>(
                          value: address,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                address.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                address.singleLineAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Divider(color: Colors.grey[300],),
                            ],
                          ),
                        )
                      ),
                    ],
                    onChanged: (Partner? address) {
                      setState(() {
                        _selectedShippingAddress = address;
                      });
                    },
                  ),
                  
                  // Preview de la dirección seleccionada
                  if (_selectedShippingAddress != null) ...[
                    const SizedBox(height: 12),
                    _buildAddressPreview(_selectedShippingAddress!),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Construye el preview de una dirección
  Widget _buildAddressPreview(Partner address) {
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
                  address.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (address.street != null) ...[
            Text(
              address.street!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (address.street2 != null && address.street2!.isNotEmpty) ...[
            Text(
              address.street2!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (address.cityName != null || address.stateName != null) ...[
            Text(
              '${address.cityName ?? address.city ?? ''}, ${address.stateName ?? ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (address.zip != null && address.zip!.isNotEmpty) ...[
            Text(
              'CP: ${address.zip}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          if (address.phone != null && address.phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  address.phone!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Muestra el dialog para crear una nueva dirección
  Future<void> _showCreateAddressDialog() async {
     if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero selecciona un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newAddress = await showModalBottomSheet<Partner>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: CreateShippingAddressDialog(
          parentPartnerId: _selectedPartner!.id,
        ),
      ),
    );

    if (newAddress != null) {
      setState(() {
        _deliveryAddresses.add(newAddress);
        _selectedShippingAddress = newAddress;
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

    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_orderLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formattedDate =
        DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');

    // Obtenemos el ID del usuario de la sesión actual
    final currentUserId = getIt<OdooSession>().userId;

    // Preparar datos de la orden
    final orderData = {
      'partner_id': _selectedPartner!.id,
      'date_order': formattedDate,
      'user_id': currentUserId,
      'state': 'sent',
      'order_line': _orderLines.map((line) => [
        0, 0, {
          'product_id': line.productId,
          'product_uom_qty': line.quantity,
          'price_unit': line.priceUnit,
        }
      ]).toList(),
    };

    // Si hay dirección de despacho seleccionada, agregarla
    if (_selectedShippingAddress != null) {
      orderData['partner_shipping_id'] = _selectedShippingAddress!.id;
      print('📦 Orden con dirección de despacho: ${_selectedShippingAddress!.name} (ID: ${_selectedShippingAddress!.id})');
    }

    print('📦 Creando orden con datos: $orderData');

    context
        .read<SaleOrderBloc>()
        .add(CreateSaleOrder(orderData: orderData));
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

