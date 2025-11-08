import '../tenant/tenant_context.dart';
import '../tenant/tenant_aware_cache.dart';
import 'audit_event.dart';

class AuditEventService {
  AuditEventService(this._tenantCache);

  final TenantAwareCache _tenantCache;

  Future<void> recordEvent({
    required String category,
    required String message,
    AuditEventLevel level = AuditEventLevel.info,
    Map<String, dynamic>? metadata,
    String? origin,
  }) async {
    if (TenantContext.currentLicenseNumber == null) {
      print('⚠️ AUDIT_EVENT_SERVICE: No se registra evento (sin tenant activo)');
      return;
    }

    final event = AuditEvent.create(
      category: category,
      level: level,
      message: message,
      metadata: metadata,
      origin: origin,
    );

    await _tenantCache.appendAuditEvent(event);
  }

  List<AuditEvent> getRecentEvents({int limit = 200}) {
    if (TenantContext.currentLicenseNumber == null) {
      return <AuditEvent>[];
    }
    return _tenantCache.getAuditEvents(limit: limit);
  }

  Future<void> clearAll() async {
    if (TenantContext.currentLicenseNumber == null) {
      return;
    }
    await _tenantCache.clearAuditEvents();
  }

  Future<void> recordInfo({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
    String? origin,
  }) async {
    await recordEvent(
      category: category,
      message: message,
      level: AuditEventLevel.info,
      metadata: metadata,
      origin: origin,
    );
  }

  Future<void> recordWarning({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
    String? origin,
  }) async {
    await recordEvent(
      category: category,
      message: message,
      level: AuditEventLevel.warning,
      metadata: metadata,
      origin: origin,
    );
  }

  Future<void> recordError({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
    String? origin,
  }) async {
    await recordEvent(
      category: category,
      message: message,
      level: AuditEventLevel.error,
      metadata: metadata,
      origin: origin,
    );
  }
}
