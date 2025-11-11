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
      final deviceId = androidInfo.id;
      
      print('📱 DEVICE_INFO: Android ID obtenido: $deviceId');
      print('📱 DEVICE_INFO: Modelo: ${androidInfo.model}');
      print('📱 DEVICE_INFO: SDK: ${androidInfo.version.sdkInt}');
      
      if (deviceId.isEmpty) {
        print('⚠️ DEVICE_INFO: Android ID está vacío');
        return null;
      }
      
      return deviceId;
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
      return {
        'id': androidInfo.id,
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

