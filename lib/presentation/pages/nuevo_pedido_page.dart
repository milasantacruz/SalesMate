import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../core/di/injection_container.dart';
import '../bloc/partner_bloc.dart';
import '../bloc/product/product_bloc.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';
import '../widgets/product_addon_widget.dart';
import '../widgets/product_search_popup.dart';
import '../widgets/partner_search_popup.dart';
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
                      _buildPartnerSelection(),
                      const SizedBox(height: 16),
                      _buildDeliveryAddressField(),
                      const SizedBox(height: 16),
                      _buildOrderLinesSection(),
                      const SizedBox(height: 16),
                       OrderTotalsWidget(
                         partnerId: _selectedPartner?.id ?? 0,
                         orderLines: List.from(_orderLines), // Crear una copia de la lista
                         isEditing: false, // Nuevo pedido no está en modo edición
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
            InkWell(
              onTap: _showPartnerSearch,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: _selectedPartner == null
                    ? Row(
                        children: [
                          Icon(Icons.person_search, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Seleccionar cliente',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                        ],
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            radius: 20,
                            child: Text(
                              _selectedPartner!.name.isNotEmpty 
                                  ? _selectedPartner!.name[0].toUpperCase() 
                                  : '?',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPartner!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_selectedPartner!.email != null && _selectedPartner!.email!.isNotEmpty)
                                  Text(
                                    _selectedPartner!.email!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                        ],
                      ),
              ),
            ),
            // Validación del campo
            if (_selectedPartner == null && _formKey.currentState?.validate() == false)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Debe seleccionar un cliente',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                  ),
                ),
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
                  InkWell(
                    onTap: _deliveryAddresses.isEmpty ? _showCreateAddressDialog : _showAddressSelector,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: _selectedShippingAddress == null
                          ? Row(
                              children: [
                                Icon(Icons.local_shipping, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _deliveryAddresses.isEmpty
                                        ? 'Sin direcciones - Crear nueva'
                                        : 'Seleccionar dirección de despacho',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                              ],
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  radius: 20,
                                  child: Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedShippingAddress!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _selectedShippingAddress!.singleLineAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                              ],
                            ),
                    ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (address.street != null && address.street!.isNotEmpty) ...[
            Text(
              address.street!,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (address.street2 != null && address.street2!.isNotEmpty) ...[
            Text(
              address.street2!,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (address.cityName != null || address.stateName != null) ...[
            Text(
              '${address.cityName ?? address.city ?? ''}, ${address.stateName ?? ''}',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (address.zip != null && address.zip!.isNotEmpty) ...[
            Text(
              'CP: ${address.zip}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (address.phone != null && address.phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address.phone!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Muestra el selector de direcciones de despacho
  Future<void> _showAddressSelector() async {
    if (_deliveryAddresses.isEmpty) {
      _showCreateAddressDialog();
      return;
    }

    await showModalBottomSheet<Partner?>(
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
                    'Dirección de Despacho',
                    style: Theme.of(context).textTheme.titleMedium,
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
                      subtitle: _selectedPartner != null 
                          ? Text(
                              '${_selectedPartner!.name} - ${_selectedPartner!.singleLineAddress}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address.singleLineAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (address.phone != null && address.phone!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  address.phone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
            parentPartnerId: _selectedPartner!.id,
            scrollController: scrollController,
          ),
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

  void _showPartnerSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PartnerBloc>()),
        ],
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: PartnerSearchPopup(
            selectedPartner: _selectedPartner,
            onPartnerSelected: (partner) {
              setState(() {
                _selectedPartner = partner;
                _selectedShippingAddress = null;
                _deliveryAddresses = [];
              });
              // Cargar direcciones de despacho del cliente
              _loadDeliveryAddresses(partner.id);
            },
          ),
        ),
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
    // Validar que se haya seleccionado un cliente
    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    final formattedDate =
        DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    
    // Obtenemos el ID del usuario de la sesión actual de forma segura
    int? currentUserId;
    try {
      if (getIt.isRegistered<OdooSession>()) {
        currentUserId = getIt<OdooSession>().userId;
      } else {
        print('⚠️ NUEVO_PEDIDO: OdooSession no está registrado, usando userId por defecto');
        currentUserId = 2; // Usuario por defecto
      }
    } catch (e) {
      print('⚠️ NUEVO_PEDIDO: Error obteniendo userId: $e, usando por defecto');
      currentUserId = 2; // Usuario por defecto
    }

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
    // Validar que se haya seleccionado un cliente
    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

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

    // Obtenemos el ID del usuario de la sesión actual de forma segura
    int? currentUserId;
    try {
      if (getIt.isRegistered<OdooSession>()) {
        currentUserId = getIt<OdooSession>().userId;
      } else {
        print('⚠️ NUEVO_PEDIDO: OdooSession no está registrado, usando userId por defecto');
        currentUserId = 2; // Usuario por defecto
      }
    } catch (e) {
      print('⚠️ NUEVO_PEDIDO: Error obteniendo userId: $e, usando por defecto');
      currentUserId = 2; // Usuario por defecto
    }

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

