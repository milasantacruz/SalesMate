import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/sale_order_model.dart';

/// Repository para manejar operaciones con Sale Orders en Odoo
class SaleOrderRepository {
  final OdooEnvironment env;
  List<SaleOrder> latestRecords = [];

  final String modelName = 'sale.order';
  List<String> get oFields => SaleOrder.oFields;

  SaleOrderRepository(this.env);

  Future<void> fetchRecords({
    int limit = 80,
    int offset = 0,
    String searchTerm = '',
    String? state,
  }) async {
    try {
      // Construcción del dominio dinámico
      final List<dynamic> domain = [];

      // Filtro por término de búsqueda (nombre del pedido o nombre del cliente)
      if (searchTerm.isNotEmpty) {
        domain.addAll([
          '|',
          ['name', 'ilike', searchTerm],
          ['partner_id', 'ilike', searchTerm]
        ]);
      }

      // Filtro por estado
      if (state != null && state.isNotEmpty) {
        domain.add(['state', '=', state]);
      }

      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'context': {'bin_size': true},
          'domain': domain,
          'fields': oFields,
          'limit': limit,
          'offset': offset,
        },
      });

      final records = response as List<dynamic>;
      latestRecords =
          records.map((json) => SaleOrder.fromJson(json)).toList();
    } on OdooException catch (e) {
      print('OdooException in SaleOrderRepository: $e');
      latestRecords = [];
    } catch (e) {
      print('Generic error in SaleOrderRepository: $e');
      latestRecords = [];
    }
  }

  Future<void> loadRecords() async {
    print('🛒 SALE_ORDER_REPO: Iniciando loadRecords()');
    await fetchRecords();
    print('✅ SALE_ORDER_REPO: fetchRecords() ejecutado');
    print('📊 SALE_ORDER_REPO: Records actuales: ${latestRecords.length}');
  }
}
