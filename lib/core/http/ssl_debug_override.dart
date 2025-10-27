import 'dart:io';

/// HTTP Override para DEBUG que permite bypass temporal de certificados SSL
/// SOLO SE DEBE USAR EN DESARROLLO - NUNCA EN PRODUCCIÓN
/// 
/// Este override permite que la aplicación ignore errores de certificado SSL
/// causados por hostname mismatches durante el desarrollo.
/// 
/// **RAZÓN**: El servidor Odoo staging tiene un certificado wildcard (*.dev.odoo.com)
/// que no cubre correctamente el hostname completo, causando errores de validación
/// especialmente en hot restart.
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Log del certificado problemático
        print('⚠️ SSL_OVERRIDE: Certificado rechazado para $host:$port');
        print('⚠️ SSL_OVERRIDE: Subject: ${cert.subject}');
        print('⚠️ SSL_OVERRIDE: Issuer: ${cert.issuer}');
        
        // PERMITIR conexión solo en desarrollo (modo debug)
        // En producción, este método debe rechazar (return false)
        print('⚠️ SSL_OVERRIDE: Permitiendo conexión (MODO DEBUG SOLO)');
        return true;
      };
  }
}

