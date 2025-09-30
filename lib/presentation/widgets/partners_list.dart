import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/partner_model.dart';
import '../bloc/partner_bloc.dart';
import '../bloc/partner_state.dart';
import '../bloc/partner_event.dart';
import 'partner_orders_popup.dart';
import '../pages/nuevo_pedido_page.dart';

/// Widget que muestra la lista de partners
class PartnersListWidget extends StatelessWidget {
  const PartnersListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PartnerBloc, PartnerState>(
      builder: (context, state) {
        // Estado de carga
        if (state is PartnerLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando partners...'),
              ],
            ),
          );
        }
        
        // Estado de operación en progreso
        if (state is PartnerOperationInProgress) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_getOperationMessage(state.operation)),
              ],
            ),
          );
        }
        
        // Estado de error
        if (state is PartnerError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<PartnerBloc>().add(LoadPartners());
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        
        // Estado vacío
        if (state is PartnerEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sin datos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<PartnerBloc>().add(RefreshPartners());
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          );
        }
        
        // Estados con datos
        List<Partner> partners = [];
        String? subtitle;
        
        if (state is PartnerLoaded) {
          partners = state.partners;
          subtitle = null; // Sin filtro por ahora
        } else if (state is PartnerSearchResult) {
          partners = state.partners;
          subtitle = 'Búsqueda: ${state.searchTerm}';
        }
        
        // Mostrar lista de partners
        if (partners.isNotEmpty) {
          return Column(
            children: [
              // Subtítulo si existe
              if (subtitle != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              
              // Lista de partners
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context.read<PartnerBloc>().add(RefreshPartners());
                  },
                  child: ListView.builder(
                    itemCount: partners.length,
                    itemBuilder: (context, index) {
                      final partner = partners[index];
                      return _buildPartnerTile(context, partner);
                    },
                  ),
                ),
              ),
            ],
          );
        }
        
        // Estado inicial
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text('Carga algunos partners para comenzar'),
            ],
          ),
        );
      },
    );
  }

  /// Construye un tile para mostrar un partner
  Widget _buildPartnerTile(BuildContext context, Partner partner) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: partner.isCompany 
                  ? Colors.blue 
                  : Colors.green,
              child: Icon(
                partner.isCompany 
                    ? Icons.business 
                    : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(
              partner.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (partner.email != null)
                  Text(
                    partner.email!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                if (partner.phone != null)
                  Text(
                    partner.phone!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (partner.isCustomer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cliente',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                    if (partner.isCustomer && partner.isSupplier)
                      const SizedBox(width: 8),
                    if (partner.isSupplier)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Proveedor',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: _buildPartnerMenu(context, partner),
            onTap: () => _showPartnerDetails(context, partner),
          ),
        ],
      ),
    );
  }

  /// Maneja las acciones del menú contextual
  void _handleMenuAction(BuildContext context, String action, Partner partner) {
    switch (action) {
      case 'history':
        _showOrderHistory(context, partner);
        break;
      case 'new_order':
        _createNewOrder(context, partner);
        break;
    }
  }

  /// Muestra los detalles del partner
  void _showPartnerDetails(BuildContext context, Partner partner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(partner.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (partner.email != null)
              Text('Email: ${partner.email}'),
            if (partner.phone != null)
              Text('Teléfono: ${partner.phone}'),
            Text('Tipo: ${partner.isCompany ? 'Empresa' : 'Persona'}'),
            Text('ID: ${partner.id}'),
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


  /// Obtiene el mensaje de la operación en progreso
  String _getOperationMessage(String operation) {
    switch (operation) {
      case 'creating':
        return 'Creando partner...';
      case 'updating':
        return 'Actualizando partner...';
      case 'deleting':
        return 'Eliminando partner...';
      default:
        return 'Procesando...';
    }
  }


  /// Construye el menú del partner con opciones de historial y nuevo pedido
  Widget _buildPartnerMenu(BuildContext context, Partner partner) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      onSelected: (value) => _handleMenuAction(context, value, partner),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'history',
          child: ListTile(
            leading: Icon(Icons.history),
            title: Text('Ver historial de pedidos'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'new_order',
          child: ListTile(
            leading: Icon(Icons.add_shopping_cart),
            title: Text('Crear nuevo pedido'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  /// Muestra el historial de pedidos del partner
  void _showOrderHistory(BuildContext context, Partner partner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.96,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
              ),
              child: PartnerOrdersPopup(
                partnerId: partner.id,
                partnerName: partner.name,
                // Si el popup soporta scrollController, pásalo; si no, su lista interna ya es scrollable
              ),
            );
          },
        );
      },
    );
  }

  /// Abre la página para crear un nuevo pedido
  void _createNewOrder(BuildContext context, Partner partner) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NuevoPedidoPage(selectedPartner: partner),
      ),
    );
  }
}

