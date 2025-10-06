import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

/// Pantalla para solicitar y validar número de licencia
class LicenseValidationPage extends StatefulWidget {
  const LicenseValidationPage({super.key});

  @override
  State<LicenseValidationPage> createState() => _LicenseValidationPageState();
}

class _LicenseValidationPageState extends State<LicenseValidationPage> {
  final _licenseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Verificar si hay un error al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = context.read<AuthBloc>().state;
      print('📱 LICENSE_PAGE: initState - Estado actual: ${currentState.runtimeType}');
      if (currentState is AuthError) {
        setState(() {
          _errorMessage = currentState.message;
        });
        print('📱 LICENSE_PAGE: Error detectado en initState: ${currentState.message}');
      }
    });
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar Licencia'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // No mostrar botón de retroceso
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          print('📱 LICENSE_PAGE: Estado recibido: ${state.runtimeType}');
          
          if (state is AuthLoading) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          } else if (state is AuthLicenseValidated) {
            setState(() {
              _isLoading = false;
              _errorMessage = null;
            });
            print('✅ LICENSE_PAGE: Licencia validada, navegando a PIN login');
            // Navegar a la pantalla de PIN login
            Navigator.of(context).pushReplacementNamed('/pin-login');
          } else if (state is AuthError) {
            print('❌ LICENSE_PAGE: Error recibido: ${state.message}');
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
            
            // Mostrar SnackBar adicional para errores críticos
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.message,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red[700],
                duration: const Duration(seconds: 8),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Cerrar',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono principal
                Icon(
                  Icons.verified_user_outlined,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                
                // Título
                Text(
                  'Sistema de Licencia',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Subtítulo
                Text(
                  'Ingrese el número de licencia para continuar',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Campo de licencia
                TextFormField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: 'Número de Licencia',
                    hintText: 'Ejemplo: POF0001',
                    prefixIcon: const Icon(Icons.security),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese el número de licencia';
                    }
                    if (value.trim().length < 6) {
                      return 'El número de licencia debe tener al menos 6 caracteres';
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
                  onFieldSubmitted: (_) => _validateLicense(),
                ),
                const SizedBox(height: 24),
                
                // Mensaje de error
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Error de Validación',
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
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
                
                // Botón de validar
                ElevatedButton(
                  onPressed: _isLoading ? null : _validateLicense,
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
                          'Validar Licencia',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                
                // Información adicional
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Información',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El número de licencia permite configurar automáticamente la conexión con su servidor Odoo.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validateLicense() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      context.read<AuthBloc>().add(
        LicenseCheckRequested(_licenseController.text.trim()),
      );
    }
  }
}
