import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/partner_bloc.dart';
import '../bloc/partner_event.dart';
import '../bloc/partner_state.dart';
import '../../../data/models/partner_model.dart';

/// Popup para buscar y seleccionar partners/clientes
class PartnerSearchPopup extends StatefulWidget {
  final Function(Partner partner) onPartnerSelected;
  final Partner? selectedPartner; // Partner preseleccionado

  const PartnerSearchPopup({
    super.key,
    required this.onPartnerSelected,
    this.selectedPartner,
  });

  @override
  State<PartnerSearchPopup> createState() => _PartnerSearchPopupState();
}

class _PartnerSearchPopupState extends State<PartnerSearchPopup> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargar todos los partners inicialmente
    context.read<PartnerBloc>().add(LoadPartners());
    
    // Si hay un partner preseleccionado, mostrarlo en el campo de búsqueda
    if (widget.selectedPartner != null) {
      _searchController.text = widget.selectedPartner!.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      // Si no hay término de búsqueda, cargar todos los partners
      context.read<PartnerBloc>().add(LoadPartners());
    } else {
      // TODO: Implementar búsqueda por término específico cuando esté disponible
      // Por ahora, cargamos todos y filtramos en el UI
      context.read<PartnerBloc>().add(LoadPartners());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seleccionar Cliente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch();
                      },
                    )
                  : null,
            ),
            onChanged: (value) => _performSearch(),
          ),
          const SizedBox(height: 16),
          
          // Lista de partners
          Expanded(
            child: BlocBuilder<PartnerBloc, PartnerState>(
              builder: (context, state) {
                if (state is PartnerLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is PartnerLoaded) {
                  final searchTerm = _searchController.text.trim().toLowerCase();
                  final filteredPartners = searchTerm.isEmpty
                      ? state.partners
                      : state.partners.where((partner) {
                          return partner.name.toLowerCase().contains(searchTerm) ||
                                 (partner.email != null && 
                                  partner.email!.toLowerCase().contains(searchTerm));
                        }).toList();

                  if (filteredPartners.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildPartnersList(filteredPartners);
                } else if (state is PartnerEmpty) {
                  return _buildEmptyState();
                } else if (state is PartnerError) {
                  return _buildErrorState(state.message);
                }

                return const Center(
                  child: Text('Cargando clientes...'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersList(List<Partner> partners) {
    return ListView.builder(
      itemCount: partners.length,
      itemBuilder: (context, index) {
        final partner = partners[index];
        final isSelected = widget.selectedPartner?.id == partner.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.blue[50] : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
              child: Text(
                partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              partner.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue[900] : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (partner.email != null && partner.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          partner.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (partner.phone != null && partner.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        partner.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (partner.singleLineAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          partner.singleLineAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.blue[700])
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              widget.onPartnerSelected(partner);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.trim().isEmpty
                ? 'No se encontraron clientes'
                : 'No se encontraron resultados',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.trim().isEmpty
                ? 'Verifique que los partners estén cargados'
                : 'Intente con otros términos de búsqueda',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error cargando clientes',
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
}
