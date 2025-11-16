import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

/// Pantalla para mostrar las credenciales de recuperación (UUID y QR)
/// 
/// Esta pantalla se muestra después de registrar exitosamente un UUID
/// en una licencia nueva. El usuario debe guardar esta información
/// para poder recuperar el acceso en caso de reinstalación.
class DeviceRecoveryKeyScreen extends StatelessWidget {
  final String uuid;
  final String licenseNumber;

  const DeviceRecoveryKeyScreen({
    super.key,
    required this.uuid,
    required this.licenseNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credenciales de Recuperación'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // No permitir retroceso
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono principal
            Icon(
              Icons.vpn_key_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            
            // Título
            Text(
              'Guarde sus Credenciales',
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Importante',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Debe guardar las siguientes credenciales para recuperar acceso en caso de reinstalación. Si pierde esta información, deberá contactar con el administrador.',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Código UUID legible
            _buildUUIDSection(context),
            const SizedBox(height: 32),
            
            // QR Code
            _buildQRCodeSection(context),
            const SizedBox(height: 32),
            
            // Botón Continuar
            ElevatedButton(
              onPressed: () => _onContinue(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUUIDSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Código de Recuperación',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // UUID con estilo monospace
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                uuid,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Botón Copiar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyUUID(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copiar Código'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Código QR',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: uuid,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Botón Descargar/Compartir
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareQR(context),
                icon: const Icon(Icons.share),
                label: const Text('Compartir QR'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyUUID(BuildContext context) {
    Clipboard.setData(ClipboardData(text: uuid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Código copiado al portapapeles'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareQR(BuildContext context) async {
    try {
      // Para compartir el QR, compartimos el UUID en formato texto
      // El usuario puede guardar el UUID y escanearlo después como QR
      await Share.share(
        'Código de recuperación para licencia $licenseNumber:\n\n$uuid\n\nGuarde este código de forma segura para recuperar el acceso.',
        subject: 'Credenciales de Recuperación - Licencia $licenseNumber',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onContinue(BuildContext context) {
    // Emitir evento para continuar el flujo después de mostrar credenciales
    final authBloc = context.read<AuthBloc>();
    final currentState = authBloc.state;
    if (currentState is AuthRecoveryKeyRequired) {
      authBloc.add(RecoveryKeyAcknowledged(
        licenseNumber: currentState.licenseNumber,
        serverUrl: currentState.serverUrl,
        database: currentState.database,
        tipoven: currentState.tipoven,
        username: currentState.username,
        password: currentState.password,
        tarifaId: currentState.tarifaId,
        empresaId: currentState.empresaId,
      ));
    }
  }
}

