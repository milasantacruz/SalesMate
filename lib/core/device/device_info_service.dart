import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio para obtener información del dispositivo
class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Obtiene el identificador único del dispositivo (Android ID)
  /// 
  /// Retorna el Android ID del dispositivo en Android.
  /// No requiere permisos especiales.
  /// 
  /// Retorna `null` si no se puede obtener el identificador.
  Future<String?> getDeviceIdentifier() async {
    try {
      if (!Platform.isAndroid) {
        print('⚠️ DEVICE_INFO: Plataforma no soportada (solo Android)');
        return null;
      }

      final androidInfo = await _deviceInfo.androidInfo;

      // Intentar obtener Android ID desde el mapa de datos interno (campo 'androidId')
      // Nota: device_info_plus expone campos adicionales a través de 'data'
      final Map<String, dynamic> raw = androidInfo.data;
      String? androidId = (raw['androidId'] as String?)?.trim();

      // Validar valor problemático conocido en APIs antiguas
      const badLegacyId = '9774d56d682e549c';
      if (androidId != null && androidId.isNotEmpty && androidId != badLegacyId) {
        print('📱 DEVICE_INFO: Android ID (Settings.Secure.ANDROID_ID) obtenido: $androidId');
        return androidId;
      }

      // Fallback: usar androidInfo.id (Build.ID) SOLO para logging/compatibilidad (no es único por dispositivo)
      final buildId = androidInfo.id;
      if (androidId == null || androidId.isEmpty) {
        print('⚠️ DEVICE_INFO: androidId no disponible en data o inválido (=$androidId)');
      } else if (androidId == badLegacyId) {
        print('⚠️ DEVICE_INFO: Detectado ANDROID_ID legacy ($badLegacyId) - no es confiable');
      }

      if (buildId.isNotEmpty && buildId.toLowerCase() != 'unknown') {
        print('⚠️ DEVICE_INFO: Fallback a Build.ID (NO único por dispositivo): $buildId');
        return buildId;
      }

      print('⚠️ DEVICE_INFO: No se pudo obtener un identificador confiable');
      return null;
    } catch (e, stackTrace) {
      print('❌ DEVICE_INFO: Error obteniendo identificador de dispositivo: $e');
      print('❌ DEVICE_INFO: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtiene información adicional del dispositivo (para debugging)
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      if (!Platform.isAndroid) {
        return null;
      }

      final androidInfo = await _deviceInfo.androidInfo;
      final Map<String, dynamic> raw = androidInfo.data;
      final androidId = (raw['androidId'] as String?)?.trim();

      return {
        'id': androidInfo.id,
        'androidId': androidId,
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'device': androidInfo.device,
        'product': androidInfo.product,
        'hardware': androidInfo.hardware,
        'sdkInt': androidInfo.version.sdkInt,
        'release': androidInfo.version.release,
        'codename': androidInfo.version.codename,
      };
    } catch (e) {
      print('❌ DEVICE_INFO: Error obteniendo información del dispositivo: $e');
      return null;
    }
  }
}

