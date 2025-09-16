import 'package:odoo_rpc/odoo_rpc.dart';

/// Implementación stub para plataformas no soportadas
OdooClient createClient(String baseUrl) {
  print('❌ PLATAFORMA NO SOPORTADA - Usando implementación por defecto');
  throw UnsupportedError('Esta plataforma no está soportada para OdooClient');
}
