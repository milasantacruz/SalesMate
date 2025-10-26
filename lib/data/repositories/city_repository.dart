import 'package:odoo_repository/odoo_repository.dart';
import '../models/city_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';

/// Repository para manejar operaciones con Cities en Odoo con soporte offline
class CityRepository extends OfflineOdooRepository<City> {
  final String modelName = 'res.city';
  late final OdooCallQueueRepository _callQueue;
  
  // Domain por defecto: solo ciudades de Chile
  List<dynamic> get oDomain => [
    ['country_id.name', '=', 'Chile']
  ];

  CityRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache) {
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => City.oFields;

  @override
  City fromJson(Map<String, dynamic> json) => City.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    print('🏙️ CITY_REPO: Buscando ciudades con domain: $oDomain');
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': oDomain,
        'fields': oFields,
        'limit': 500, // Chile tiene ~346 comunas
        'offset': 0,
        'order': 'name'
      },
    });
    
    final records = response as List<dynamic>;
    print('🏙️ CITY_REPO: ${records.length} ciudades encontradas');
    
    return records;
  }

  /// Obtiene la lista actual de ciudades
  List<City> get currentCities => latestRecords;

  /// Obtiene todas las ciudades de Chile (carga desde servidor o cache)
  Future<List<City>> getChileanCities() async {
    await fetchRecords();
    return latestRecords;
  }

  /// Busca ciudades por nombre
  Future<List<City>> searchCitiesByName(String query) async {
    if (query.isEmpty) {
      return latestRecords;
    }
    
    print('🔍 CITY_REPO: searchCitiesByName() - query: "$query"');
    print('📊 CITY_REPO: latestRecords.length: ${latestRecords.length}');
    print('💾 CITY_REPO: latestRecords.isNotEmpty: ${latestRecords.isNotEmpty}');
    
    // Si ya tenemos ciudades en cache, buscar localmente
    if (latestRecords.isNotEmpty) {
      print('✅ CITY_REPO: Buscando localmente en cache');
      final queryLower = query.toLowerCase();
      final results = latestRecords
          .where((city) => city.name.toLowerCase().contains(queryLower))
          .toList();
      print('✅ CITY_REPO: ${results.length} resultados encontrados localmente');
      return results;
    }
    
    // Si no hay cache, buscar en servidor con filtro
    print('⚠️ CITY_REPO: Cache vacío - intentando búsqueda remota (esto fallará en offline)');
    try {
      print('🏙️ CITY_REPO: Buscando ciudades por nombre: $query');
      
      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['country_id.name', '=', 'Chile'],
            ['name', 'ilike', query]
          ],
          'fields': oFields,
          'limit': 50,
          'order': 'name'
        },
      });
      
      final records = response as List<dynamic>;
      final cities = records.map((record) => fromJson(record)).toList();
      
      print('🏙️ CITY_REPO: ${cities.length} ciudades encontradas para "$query"');
      return cities;
    } catch (e) {
      print('❌ CITY_REPO: Error buscando ciudades: $e');
      return [];
    }
  }

  /// Obtiene una ciudad por ID
  Future<City?> getCityById(int id) async {
    await fetchRecords();
    try {
      return currentCities.firstWhere((city) => city.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene ciudades de una región específica
  Future<List<City>> getCitiesByState(int stateId) async {
    await fetchRecords();
    return latestRecords.where((city) => city.stateId == stateId).toList();
  }

  /// Dispara la carga de records desde el servidor (con soporte offline)
  Future<void> loadRecords() async {
    print('🏙️ CITY_REPO: Iniciando loadRecords() con soporte offline');
    print('🏙️ CITY_REPO: Modelo: $modelName');

    try {
      print('⏳ CITY_REPO: Llamando fetchRecords()...');
      await fetchRecords(); // Usa el método de la clase base con lógica offline
      print('✅ CITY_REPO: fetchRecords() ejecutado');
      print('📊 CITY_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ CITY_REPO: Error en loadRecords(): $e');
      print('❌ CITY_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Obtiene lista de regiones únicas
  List<String> getUniqueStates() {
    final states = <String>{};
    for (final city in latestRecords) {
      if (city.stateName != null && city.stateName!.isNotEmpty) {
        states.add(city.stateName!);
      }
    }
    return states.toList()..sort();
  }

  /// Obtiene el código postal más común de una ciudad
  String? getDefaultZipcode(int cityId) {
    try {
      final city = currentCities.firstWhere((c) => c.id == cityId);
      return city.zipcode;
    } catch (e) {
      return null;
    }
  }

  /// Crea una nueva ciudad (offline/online según conectividad)
  Future<String> createCity(City city) async {
    return await _callQueue.createRecord(modelName, city.toJson());
  }

  /// Actualiza una ciudad existente (offline/online según conectividad)
  Future<void> updateCity(City city) async {
    await _callQueue.updateRecord(modelName, city.id, city.toJson());
  }

  /// Elimina permanentemente una ciudad (offline/online según conectividad)
  Future<void> deleteCity(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }
}

