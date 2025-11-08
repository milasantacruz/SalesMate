import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';

/// OdooClient extendido para aplicar automáticamente el contexto de compañía.
class ScopedOdooClient extends OdooClient {
  ScopedOdooClient(
    String baseURL, {
    OdooSession? sessionId,
    http.BaseClient? httpClient,
    bool isWebPlatform = false,
  }) : super(
          baseURL,
          sessionId: sessionId,
          httpClient: httpClient,
          isWebPlatform: isWebPlatform,
        );

  int? _companyId;
  int? _userId;

  /// Configura el scope de compañía para futuras llamadas RPC.
  void setCompanyScope(int? companyId) {
    _companyId = companyId;
    if (_companyId != null) {
      print('🏢 ScopedOdooClient: companyScope establecido en $_companyId');
    } else {
      print('🏢 ScopedOdooClient: companyScope limpiado (sin filtro)');
    }
  }

  int? get companyScope => _companyId;

  void setUserScope(int? userId) {
    _userId = userId;
    if (_userId != null) {
      print('👤 ScopedOdooClient: userScope establecido en $_userId');
    } else {
      print('👤 ScopedOdooClient: userScope limpiado (sin filtro)');
    }
  }

  int? get userScope => _userId;

  @override
  Future<dynamic> callKw(dynamic params) {
    if (params is! Map) {
      return super.callKw(params);
    }

    final scopedParams = Map<String, dynamic>.from(params);
    final kwargs =
        Map<String, dynamic>.from((scopedParams['kwargs'] as Map?) ?? <String, dynamic>{});
    final context =
        Map<String, dynamic>.from((kwargs['context'] as Map?) ?? <String, dynamic>{});

    if (_companyId != null) {
      context['company_id'] = _companyId;
      context['allowed_company_ids'] = <int>[_companyId!];
    }
    if (_userId != null) {
      context['uid'] = _userId;
    }

    kwargs['context'] = context;
    scopedParams['kwargs'] = kwargs;

    return super.callKw(scopedParams);
  }
}

