import 'package:flutter/material.dart';
import '../../core/di/injection_container.dart';
import '../../data/models/city_model.dart';
import '../../data/models/partner_model.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/city_repository.dart';

/// Dialog para crear una nueva dirección de despacho
class CreateShippingAddressDialog extends StatefulWidget {
  final int parentPartnerId;
  
  const CreateShippingAddressDialog({
    super.key,
    required this.parentPartnerId,
  });

  @override
  State<CreateShippingAddressDialog> createState() => _CreateShippingAddressDialogState();
}

class _CreateShippingAddressDialogState extends State<CreateShippingAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _street2Controller = TextEditingController();
  final _citySearchController = TextEditingController();
  final _zipController = TextEditingController();
  final _phoneController = TextEditingController();
  
  City? _selectedCity;
  List<City> _citySearchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _citySearchController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCities() async {
    try {
      final cityRepo = getIt<CityRepository>();
      final cities = await cityRepo.getChileanCities();
      if (mounted) {
        setState(() {
          _citySearchResults = cities.take(50).toList();
        });
      }
    } catch (e) {
      print('❌ Error cargando ciudades: $e');
    }
  }

  Future<void> _searchCities(String query) async {
    if (query.isEmpty) {
      await _loadInitialCities();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final cityRepo = getIt<CityRepository>();
      final results = await cityRepo.searchCitiesByName(query);
      
      if (mounted) {
        setState(() {
          _citySearchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ Error buscando ciudades: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _createAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCity == null) {
      _showError('Por favor selecciona una comuna');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final partnerRepo = getIt<PartnerRepository>();
      
      final addressData = {
        'name': _nameController.text.trim(),
        'parent_id': widget.parentPartnerId,
        'type': 'delivery',
        'street': _streetController.text.trim(),
        'street2': _street2Controller.text.trim().isNotEmpty 
            ? _street2Controller.text.trim() 
            : null,
        'city': _selectedCity!.name,
        'city_id': _selectedCity!.id,
        'state_id': _selectedCity!.stateId,
        'country_id': 46, // Chile
        'zip': _zipController.text.trim().isNotEmpty 
            ? _zipController.text.trim() 
            : null,
        'phone': _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
      };

      print('📍 Creando dirección: $addressData');
      
      final newAddress = await partnerRepo.createDeliveryAddress(addressData);
      
      if (newAddress != null && mounted) {
        Navigator.of(context).pop(newAddress);
      } else {
        _showError('No se pudo crear la dirección');
        setState(() {
          _isCreating = false;
        });
      }
    } catch (e) {
      print('❌ Error creando dirección: $e');
      _showError('Error al crear dirección: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_location, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nueva Dirección de Despacho',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
    
        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nombre/Alias
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre/Alias de la dirección *',
                      hintText: 'Ej: Oficina Principal, Bodega 1',
                      prefixIcon: const Icon(Icons.label),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese un nombre para la dirección';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Calle
                  TextFormField(
                    controller: _streetController,
                    decoration: InputDecoration(
                      labelText: 'Calle y Número *',
                      hintText: 'Ej: Av. Libertador 1234',
                      prefixIcon: const Icon(Icons.home),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese la calle y número';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Depto/Oficina
                  TextFormField(
                    controller: _street2Controller,
                    decoration: InputDecoration(
                      labelText: 'Depto/Oficina (opcional)',
                      hintText: 'Ej: Depto 305, Oficina B',
                      prefixIcon: const Icon(Icons.apartment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
    
                  // Comuna (Autocomplete)
                  Autocomplete<City>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _citySearchResults;
                      }
                      _searchCities(textEditingValue.text);
                      return _citySearchResults;
                    },
                    displayStringForOption: (city) => city.displayName,
                    onSelected: (city) {
                      setState(() {
                        _selectedCity = city;
                        // Autocompletar código postal si existe
                        if (city.zipcode != null && city.zipcode!.isNotEmpty) {
                          _zipController.text = city.zipcode!;
                        }
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _citySearchController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Comuna *',
                          hintText: 'Buscar comuna...',
                          prefixIcon: const Icon(Icons.location_city),
                          suffixIcon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _selectedCity != null
                                  ? Icon(Icons.check_circle, color: Colors.green[600])
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (_selectedCity == null) {
                            return 'Selecciona una comuna de la lista';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 400,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final city = options.elementAt(index);
                                return ListTile(
                                  leading: const Icon(Icons.location_on, size: 20),
                                  title: Text(city.name),
                                  subtitle: city.stateName != null
                                      ? Text(
                                          city.stateName!,
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : null,
                                  onTap: () => onSelected(city),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Información de región (readonly)
                  if (_selectedCity != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, 
                            size: 16, 
                            color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Región: ${_selectedCity!.stateName ?? "No especificada"}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
    
                  // Código Postal
                  TextFormField(
                    controller: _zipController,
                    decoration: InputDecoration(
                      labelText: 'Código Postal (opcional)',
                      hintText: 'Ej: 1234567',
                      prefixIcon: const Icon(Icons.markunread_mailbox),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
    
                  // Teléfono
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      hintText: 'Ej: +56 9 1234 5678',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
    
                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCreating 
                              ? null 
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createAddress,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check, size: 20),
                                    SizedBox(width: 8),
                                    Text('Crear Dirección'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

