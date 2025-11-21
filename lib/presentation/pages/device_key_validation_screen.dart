import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/device/device_recovery_service.dart';

/// Pantalla para validar la key de recuperación
/// 
/// Esta pantalla se muestra cuando `license.imei != null` pero no hay UUID en cache
/// o el UUID en cache no coincide con el de la licencia. El usuario debe ingresar
/// la key de recuperación para validar su identidad.
class DeviceKeyValidationScreen extends StatefulWidget {
  final String licenseNumber;
  final String expectedUUID;

  const DeviceKeyValidationScreen({
    super.key,
    required this.licenseNumber,
    required this.expectedUUID,
  });

  @override
  State<DeviceKeyValidationScreen> createState() => _DeviceKeyValidationScreenState();
}

class _DeviceKeyValidationScreenState extends State<DeviceKeyValidationScreen> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _keyController.addListener(() {
      if (_errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar Key de Recuperación'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // No permitir retroceso
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLicenseValidated) {
            // Key validada exitosamente, navegar a PIN login
            Navigator.of(context).pushReplacementNamed('/pin-login');
          } else if (state is AuthError) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono principal
                Icon(
                  Icons.vpn_key,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                
                // Título
                Text(
                  'Validar Identidad',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Mensaje explicativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La licencia ya tiene un dispositivo asignado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingrese la key de recuperación para validar su identidad. Si perdió la clave, debe comunicarse con el administrador.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Input de key
                TextFormField(
                  controller: _keyController,
                  decoration: InputDecoration(
                    labelText: 'Key de Recuperación',
                    hintText: '550e8400-e29b-41d4-a716-446655440000',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese la key de recuperación';
                    }
                    final deviceRecoveryService = getIt<DeviceRecoveryService>();
                    if (!deviceRecoveryService.isValidUUID(value.trim())) {
                      return 'Formato de UUID inválido';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _validateKey(),
                ),
                const SizedBox(height: 24),
                
                // Mensaje de error
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Botón Validar
                ElevatedButton(
                  onPressed: _isLoading ? null : _validateKey,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Validar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                
                // Botón Cancelar
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          // Emitir evento al BLoC para cancelar validación
                          // El BLoC emitirá AuthUnauthenticated y el BlocBuilder
                          // en main.dart mostrará automáticamente la pantalla de licencia
                          context.read<AuthBloc>().add(
                            KeyValidationCancelled(
                              licenseNumber: widget.licenseNumber,
                            ),
                          );
                        },
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validateKey() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final deviceRecoveryService = getIt<DeviceRecoveryService>();
    final enteredKey = _keyController.text.trim();
    
    // Validar que no esté vacío
    if (enteredKey.isEmpty) {
      setState(() {
        _errorMessage = 'Debe ingresar una key de recuperación';
      });
      return;
    }
    
    // Validar formato
    if (!deviceRecoveryService.isValidUUID(enteredKey)) {
      setState(() {
        _errorMessage = 'Formato de UUID inválido. Debe tener el formato: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
      });
      return;
    }
    
    // Comparar con el UUID esperado (license.imei)
    if (!deviceRecoveryService.compareUUIDs(enteredKey, widget.expectedUUID)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Key inválida. Si perdió su clave de recuperación, debe comunicarse con el administrador.';
      });
      
      // Emitir error en AuthBloc
      context.read<AuthBloc>().add(
        KeyValidationFailed(
          licenseNumber: widget.licenseNumber,
          enteredKey: enteredKey,
        ),
      );
      return;
    }
    
    // Key válida - guardar en cache y continuar
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Guardar en cache y emitir evento de validación exitosa
    deviceRecoveryService.storeUUID(enteredKey).then((_) {
      if (mounted) {
        context.read<AuthBloc>().add(
          KeyValidationSucceeded(
            licenseNumber: widget.licenseNumber,
            uuid: enteredKey,
          ),
        );
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al guardar la key: ${error.toString()}. Por favor, intente nuevamente.';
        });
      }
    });
  }
}

