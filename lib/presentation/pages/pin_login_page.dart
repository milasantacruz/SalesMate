import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

/// Pantalla para login por PIN de empleado
class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login por PIN'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Mostrar mensaje de bienvenida
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Bienvenido ${state.username}!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // Login exitoso, navegar a la aplicación principal después de un breve delay
            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.of(context).pushReplacementNamed('/home');
            });
          } else if (state is AuthError) {
            setState(() {
              _errorMessage = state.message;
            });
            // Limpiar PIN en caso de error
            setState(() {
              _pin = '';
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icono principal
              Icon(
                Icons.pin,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              
              // Título
              Text(
                'Login por PIN',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Subtítulo
              Text(
                'Ingrese su PIN de empleado',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Display del PIN
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: index < _pin.length ? Colors.black : Colors.transparent,
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              
              // Mensaje de error
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Teclado numérico
              _buildNumericKeypad(),
              const SizedBox(height: 16),
              
              // Información adicional
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Empleado',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingrese su PIN personal para acceder al sistema.',
                        style: TextStyle(
                          color: Colors.green[700],
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
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        // Filas del 1-9
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int col = 0; col < 3; col++)
                _buildNumericButton('${row * 3 + col + 1}'),
            ],
          ),
        
        // Fila con 0 y botones especiales
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumericButton('0'),
            _buildBackspaceButton(),
            _buildSubmitButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericButton(String number) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _addDigit(number),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: _removeDigit,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.orange,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _pin.length == 4;
    
    return Container(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: canSubmit ? _submitPin : null,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: canSubmit ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.check,
            color: canSubmit ? Colors.white : Colors.grey[400],
            size: 24,
          ),
        ),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null; // Limpiar error al ingresar dígito
      });
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null; // Limpiar error al borrar dígito
      });
    }
  }

  void _submitPin() {
    if (_pin.length == 4) {
      context.read<AuthBloc>().add(EmployeePinLoginRequested(_pin));
    }
  }
}
