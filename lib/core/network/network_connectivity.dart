import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Implementación de conectividad de red para Odoo Repository
class NetworkConnectivity implements NetConnState {
  static NetworkConnectivity? _singleton;
  static late Connectivity _connectivity;

  factory NetworkConnectivity() {
    _singleton ??= NetworkConnectivity._();
    return _singleton!;
  }

  NetworkConnectivity._() {
    _connectivity = Connectivity();
  }

  @override
  Future<netConnState> checkNetConn() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi) {
        return netConnState.online;
      }
      return netConnState.offline;
    } catch (e) {
      // En caso de error, asumir offline
      return netConnState.offline;
    }
  }

  @override
  Stream<netConnState> get onNetConnChanged async* {
    try {
      await for (var netState in _connectivity.onConnectivityChanged) {
        if (netState == ConnectivityResult.mobile ||
            netState == ConnectivityResult.wifi) {
          // Went online
          yield netConnState.online;
        } else if (netState == ConnectivityResult.none) {
          // Went offline
          yield netConnState.offline;
        }
      }
    } catch (e) {
      // En caso de error, emitir offline
      yield netConnState.offline;
    }
  }
}
