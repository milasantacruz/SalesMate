import 'package:odoo_rpc/odoo_rpc.dart';
import 'odoo_client_stub.dart'
    if (dart.library.html) 'odoo_client_web.dart'
    if (dart.library.io) 'odoo_client_mobile.dart';

/// Factory para crear OdooClient según la plataforma
abstract class OdooClientFactory {
  /// Crea un OdooClient configurado para la plataforma actual
  static OdooClient create(String baseUrl) {
    print('🏭 OdooClientFactory: Creando cliente para plataforma actual');
    return createClient(baseUrl);
  }
}