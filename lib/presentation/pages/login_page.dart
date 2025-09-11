import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../../core/constants/app_constants.dart';

/// Página de login con formulario de autenticación
class LoginPage extends StatefulWidget {
  final String? errorMessage;
  
  const LoginPage({super.key, this.errorMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _databaseController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    // Inicializar con valores por defecto
    _serverUrlController.text = AppConstants.odooServerURL;
    _databaseController.text = AppConstants.odooDbName;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginRequested(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          serverUrl: _showAdvancedSettings ? _serverUrlController.text.trim() : null,
          database: _showAdvancedSettings ? _databaseController.text.trim() : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        centerTitle: true,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Stack(
              children: [
                _buildLoginForm(),
                if (state is AuthLoading) _buildLoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo o título
                  const Icon(
                    Icons.business,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Odoo Test App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Campo Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Usuario requerido';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Contraseña requerida';
                      }
                      if (value.length < 6) {
                        return 'Contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitLogin(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Configuración avanzada (expandible)
                  ExpansionTile(
                    title: const Text('Configuración Avanzada'),
                    leading: const Icon(Icons.settings),
                    onExpansionChanged: (expanded) {
                      setState(() => _showAdvancedSettings = expanded);
                    },
                    children: [
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL del Servidor',
                          prefixIcon: Icon(Icons.cloud),
                          border: OutlineInputBorder(),
                          helperText: 'Dejar vacío para usar configuración por defecto',
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!Uri.tryParse(value)!.hasAbsolutePath) {
                              return 'URL inválida';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _databaseController,
                        decoration: const InputDecoration(
                          labelText: 'Base de Datos',
                          prefixIcon: Icon(Icons.storage),
                          border: OutlineInputBorder(),
                          helperText: 'Dejar vacío para usar configuración por defecto',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Iniciar Sesión',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  // Mostrar error inicial si existe
                  if (widget.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.errorMessage!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Autenticando...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
