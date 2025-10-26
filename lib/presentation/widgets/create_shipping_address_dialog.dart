import 'package:flutter/material.dart';
import '../../core/di/injection_container.dart';
import '../../data/models/city_model.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/city_repository.dart';

/// Dialog para crear una nueva dirección de despacho
class CreateShippingAddressDialog extends StatefulWidget {
  final int parentPartnerId;
  final ScrollController? scrollController;
  
  const CreateShippingAddressDialog({
    super.key,
    required this.parentPartnerId,
    this.scrollController,
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
  
  // Focus nodes para manejar el scroll automático
  final _nameFocusNode = FocusNode();
  final _streetFocusNode = FocusNode();
  final _street2FocusNode = FocusNode();
  final _cityFocusNode = FocusNode();
  final _zipFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  
  City? _selectedCity;
  List<City> _citySearchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialCities();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _nameFocusNode.addListener(() => _onFocusChanged(_nameFocusNode, 0));
    _streetFocusNode.addListener(() => _onFocusChanged(_streetFocusNode, 1));
    _street2FocusNode.addListener(() => _onFocusChanged(_street2FocusNode, 2));
    _cityFocusNode.addListener(() => _onFocusChanged(_cityFocusNode, 3));
    _zipFocusNode.addListener(() => _onFocusChanged(_zipFocusNode, 4));
    _phoneFocusNode.addListener(() => _onFocusChanged(_phoneFocusNode, 5));
  }

  void _onFocusChanged(FocusNode focusNode, int fieldIndex) {
    if (focusNode.hasFocus && widget.scrollController != null) {
      // Hacer scroll para mostrar el campo enfocado
      Future.delayed(const Duration(milliseconds: 300), () {
        if (widget.scrollController!.hasClients) {
          final double scrollPosition = fieldIndex * 80.0; // Aproximadamente 80px por campo
          widget.scrollController!.animateTo(
            scrollPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _citySearchController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    
    _nameFocusNode.dispose();
    _streetFocusNode.dispose();
    _street2FocusNode.dispose();
    _cityFocusNode.dispose();
    _zipFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCities() async {
    try {
      print('🏙️ DIALOG: Cargando ciudades iniciales...');
      final cityRepo = getIt<CityRepository>();
      print('🏙️ DIALOG: Obteniendo CityRepository');
      
      final cities = await cityRepo.getChileanCities();
      print('🏙️ DIALOG: getChileanCities() retornó ${cities.length} ciudades');
      
      if (mounted) {
        setState(() {
          _citySearchResults = cities.take(50).toList();
          print('🏙️ DIALOG: _citySearchResults actualizado: ${_citySearchResults.length}');
        });
      }
    } catch (e, stackTrace) {
      print('❌ DIALOG: Error cargando ciudades: $e');
      print('❌ DIALOG: Stack trace: $stackTrace');
    }
  }

  Future<void> _searchCities(String query) async {
    if (query.isEmpty) {
      await _loadInitialCities();
      return;
    }

    print('🔍 Buscando ciudades con query: "$query"');
    setState(() {
      _isSearching = true;
    });

    try {
      final cityRepo = getIt<CityRepository>();
      final results = await cityRepo.searchCitiesByName(query);
      print('🔍 Resultados encontrados: ${results.length}');
      
      if (mounted) {
        setState(() {
          _citySearchResults = results;
          _isSearching = false;
        });
        print('🔍 _citySearchResults actualizado: ${_citySearchResults.length}');
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
      print('📍 DIALOG: _createAddress() iniciado');
      final partnerRepo = getIt<PartnerRepository>();
      print('📍 DIALOG: PartnerRepository obtenido');
      
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

      print('📍 DIALOG: Dirección a crear: $addressData');
      print('📍 DIALOG: Llamando a createDeliveryAddress()...');
      
      final newAddress = await partnerRepo.createDeliveryAddress(addressData);
      
      print('📍 DIALOG: createDeliveryAddress() retornó: ${newAddress != null}');
      
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
            controller: widget.scrollController,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nombre/Alias
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    textInputAction: TextInputAction.next,
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
                    onFieldSubmitted: (_) => _streetFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
    
                  // Calle
                  TextFormField(
                    controller: _streetController,
                    focusNode: _streetFocusNode,
                    textInputAction: TextInputAction.next,
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
                    onFieldSubmitted: (_) => _street2FocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
    
                  // Depto/Oficina
                  TextFormField(
                    controller: _street2Controller,
                    focusNode: _street2FocusNode,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Depto/Oficina (opcional)',
                      hintText: 'Ej: Depto 305, Oficina B',
                      prefixIcon: const Icon(Icons.apartment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onFieldSubmitted: (_) => _cityFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
    
                  // Comuna (Búsqueda personalizada)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _citySearchController,
                        focusNode: _cityFocusNode,
                        textInputAction: TextInputAction.next,
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
                        onFieldSubmitted: (_) => _zipFocusNode.requestFocus(),
                        onChanged: (value) {
                          // Si el usuario está editando el texto y ya había una ciudad seleccionada,
                          // limpiar la selección para permitir nueva búsqueda
                          if (_selectedCity != null && value != _selectedCity!.displayName) {
                            setState(() {
                              _selectedCity = null;
                            });
                          }
                          
                          if (value.isNotEmpty) {
                            _searchCities(value);
                          } else {
                            _loadInitialCities();
                          }
                        },
                        onTap: () {
                          if (_citySearchResults.isEmpty) {
                            _loadInitialCities();
                          }
                        },
                      ),
                      
                      // Lista de resultados
                      if (_citySearchResults.isNotEmpty && 
                          _citySearchController.text.isNotEmpty && 
                          (_selectedCity == null || _citySearchController.text != _selectedCity?.displayName))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _citySearchResults.length,
                            itemBuilder: (context, index) {
                              final city = _citySearchResults[index];
                              final isSelected = _selectedCity?.id == city.id;
                              
                              return InkWell(
                                onTap: () {
                                  print('🏙️ City selected: ${city.name}');
                                  setState(() {
                                    _selectedCity = city;
                                    _citySearchController.text = city.displayName;
                                    // Autocompletar código postal si existe
                                    if (city.zipcode != null && city.zipcode!.isNotEmpty) {
                                      _zipController.text = city.zipcode!;
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue[50] : Colors.transparent,
                                    border: index < _citySearchResults.length - 1
                                        ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: isSelected ? Colors.blue[700] : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              city.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                                color: isSelected ? Colors.blue[700] : Colors.black87,
                                              ),
                                            ),
                                            if (city.stateName != null)
                                              Text(
                                                city.stateName!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.blue[700],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
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
                    focusNode: _zipFocusNode,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Código Postal (opcional)',
                      hintText: 'Ej: 1234567',
                      prefixIcon: const Icon(Icons.markunread_mailbox),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
    
                  // Teléfono
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      hintText: 'Ej: +56 9 1234 5678',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    onFieldSubmitted: (_) => _createAddress(),
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

