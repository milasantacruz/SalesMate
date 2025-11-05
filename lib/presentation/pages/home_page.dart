import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:motion_tab_bar_v2/motion-tab-controller.dart';
// motion_tab_bar_v2 removido para solución custom de un solo botón
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
// Imports de Partner removidos por no uso en esta vista
import '../widgets/partners_list.dart';
import '../widgets/employees_list.dart';
import '../widgets/sale_orders_list.dart';
import '../widgets/products_list.dart';
import 'nuevo_pedido_page.dart';
import 'offline_test_page.dart';
import '../../core/di/injection_container.dart';
import '../../core/sync/sync_marker_store.dart';
import '../../core/sync/incremental_sync_coordinator.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/sale_order_repository.dart';

/// Página principal de la aplicación
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  late MotionTabBarController _actionBarController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Bottom action bar controller (3 items, center active)
    _actionBarController = MotionTabBarController(
      initialIndex: 1,
      length: 3,
      vsync: this,
    );
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // Forzar reconstrucción del widget cuando cambie el tab
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _actionBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SalesMate'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.business),
              text: 'Partners',
            ),
            Tab(
              icon: Icon(Icons.people),
              text: 'Empleados',
            ),
            Tab(
              icon: Icon(Icons.shopping_cart),
              text: 'Pedidos',
            ),
            Tab(
              icon: Icon(Icons.inventory_2),
              text: 'Productos',
            ),
          ],
        ),
        actions: [
          // Mostrar nombre del empleado
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: Chip(
                      avatar: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 16),
                      ),
                      label: Text(
                        state.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.blue[700],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Botón de búsqueda
          /*IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),*/
          // Acción Offline trasladada al MotionTabBar
          // Menú de filtros
          /*PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _handleFilterSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: _currentFilter == 'all' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Todos',
                      style: TextStyle(
                        color: _currentFilter == 'all' ? Theme.of(context).primaryColor : null,
                        fontWeight: _currentFilter == 'all' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'customers',
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: _currentFilter == 'customers' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Clientes',
                      style: TextStyle(
                        color: _currentFilter == 'customers' ? Theme.of(context).primaryColor : null,
                        fontWeight: _currentFilter == 'customers' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'suppliers',
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: _currentFilter == 'suppliers' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proveedores',
                      style: TextStyle(
                        color: _currentFilter == 'suppliers' ? Theme.of(context).primaryColor : null,
                        fontWeight: _currentFilter == 'suppliers' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'companies',
                child: Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: _currentFilter == 'companies' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Empresas',
                      style: TextStyle(
                        color: _currentFilter == 'companies' ? Theme.of(context).primaryColor : null,
                        fontWeight: _currentFilter == 'companies' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),*/
          // Menú de usuario
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _showLogoutConfirmation(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuario: ${state.username}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'DB: ${state.database}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PartnersListWidget(),
          EmployeesList(),
          SaleOrdersList(),
          ProductsList(),
        ],
      ),
      bottomNavigationBar: Tooltip(
        message: _getCreateActionTooltip(),
        child: MotionTabBar(
          controller: _actionBarController,
          initialSelectedTab: 'Nuevo',
          useSafeArea: true,
          labelAlwaysVisible: true,
          labels: const ['Sync', 'Nuevo', 'Offline'],
          iconWidgets: [
            const Icon(Icons.science, color: Colors.white, size: 28.0),
            const Icon(Icons.add, color: Colors.black, size: 32.0), // Siempre negro y más grande
            const Icon(Icons.offline_bolt, color: Colors.white, size: 28.0),
          ],
          textStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
          tabBarColor: Theme.of(context).colorScheme.primary,
          tabSelectedColor: Colors.white, // círculo de selección en el centro
          tabIconSelectedColor: Colors.black,
          tabIconColor: Colors.white,
          tabSize: 60,
          tabBarHeight: 65,
          tabIconSize: 28.0,
          tabIconSelectedSize: 32.0,
          onTabItemSelected: (int index) {
            if (index == 0) {
              _runIncrementalSyncTests();
              setState(() { _actionBarController.index = 1; });
            } else if (index == 1) {
              _onCreateAction();
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OfflineTestPage()),
              ).then((_) {
                if (mounted) {
                  setState(() { _actionBarController.index = 1; });
                }
              });
            }
          },
        ),
      ),
    );
  }

  // Manejo de filtros no utilizado en esta pantalla

  // Texto de acción no usado (solo tooltip dinámico)

  String _getCreateActionTooltip() {
    final currentIndex = _tabController.index;
    switch (currentIndex) {
      case 0:
        return 'Crear partner';
      case 1:
        return 'Crear empleado';
      case 2:
        return 'Nuevo pedido';
      case 3:
        return 'Crear producto';
      default:
        return 'Crear';
    }
  }

  void _onCreateAction() {
    final currentIndex = _tabController.index;
    if (currentIndex == 0) {
      _showCreatePartnerDialog();
    } else if (currentIndex == 1) {
      _showCreateEmployeeDialog();
    } else if (currentIndex == 2) {
      _showCreateSaleOrderDialog();
    } else if (currentIndex == 3) {
      _showCreateProductDialog();
    }
  }

  /// Muestra el diálogo de búsqueda
  /*void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar Partners'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Término de búsqueda',
                hintText: 'Ingresa nombre o email',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        Navigator.of(context).pop();
                        context.read<PartnerBloc>().add(
                          SearchPartnersByName(_searchController.text),
                        );
                        _searchController.clear();
                      }
                    },
                    icon: const Icon(Icons.person_search),
                    label: const Text('Por Nombre'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        Navigator.of(context).pop();
                        context.read<PartnerBloc>().add(
                          SearchPartnersByEmail(_searchController.text),
                        );
                        _searchController.clear();
                      }
                    },
                    icon: const Icon(Icons.email),
                    label: const Text('Por Email'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchController.clear();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }*/

  /// Muestra el diálogo para crear un nuevo partner
  void _showCreatePartnerDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isCompany = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crear Nuevo Partner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ingresa el nombre',
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+1234567890',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Es una empresa'),
                  subtitle: const Text('Marca si es una empresa en lugar de una persona'),
                  value: isCompany,
                  onChanged: (value) {
                    setState(() {
                      isCompany = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  // Por ahora solo mostramos un mensaje ya que la creación real
                  // se implementará cuando tengamos acceso completo a la API
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Función de creación en desarrollo'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra la confirmación de logout
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  /// Muestra el diálogo para crear un nuevo empleado
  void _showCreateEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Empleado'),
        content: const Text('Funcionalidad de crear empleado próximamente...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Muestra el diálogo para crear una nueva orden de venta
  void _showCreateSaleOrderDialog() {
    // Proveer los BLoCs explícitamente en la nueva ruta
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NuevoPedidoPage(),
      ),
    );
  }

  /// Muestra el diálogo para crear un nuevo producto
  void _showCreateProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Producto'),
        content: const Text('Funcionalidad de crear producto próximamente...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Ejecuta tests de Incremental Sync
  Future<void> _runIncrementalSyncTests() async {
    print('🧪 ===== INICIANDO TESTS DE INCREMENTAL SYNC =====');
    
    try {
      // Test 2: Leer marcadores
      final markerStore = getIt<SyncMarkerStore>();
      print('\n🔍 TEST 2: Marcadores encontrados:');
      final markers = markerStore.getAllMarkers();
      for (final entry in markers.entries) {
        print('   ${entry.key}: ${entry.value}');
      }
      
      if (markers.isEmpty) {
        print('⚠️ No hay marcadores. Ejecutar bootstrap primero.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay marcadores. Ejecuta bootstrap primero (haz login).'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Test 3: Ejecutar incremental sync
      print('\n🔄 TEST 3: Ejecutando incremental sync...');
      final incrementalSync = getIt<IncrementalSyncCoordinator>();
      
      incrementalSync.onProgress = (state) {
        print('📊 Progreso: ${state.progressPercent}%');
        for (final entry in state.modules.entries) {
          final status = entry.value;
          if (status.completed) {
            print('   ✅ ${entry.key.displayName}: ${status.recordsFetched} fetched, ${status.recordsMerged} merged');
          }
        }
      };
      
      final startTime = DateTime.now();
      final result = await incrementalSync.run();
      final duration = DateTime.now().difference(startTime);
      
      print('\n✅ TEST 3: Incremental sync completado');
      print('   Total fetched: ${result.totalRecordsFetched}');
      print('   Total merged: ${result.totalRecordsMerged}');
      print('   Duración: ${duration.inSeconds}s');
      
      // Test 4: Verificar conteos
      print('\n🔍 TEST 4: Verificando conteos...');
      final partnerRepo = getIt<PartnerRepository>();
      await partnerRepo.loadRecords();
      print('   Partners totales: ${partnerRepo.latestRecords.length}');
      
      final productRepo = getIt<ProductRepository>();
      await productRepo.loadRecords();
      print('   Products totales: ${productRepo.latestRecords.length}');
      
      final employeeRepo = getIt<EmployeeRepository>();
      await employeeRepo.loadRecords();
      print('   Employees totales: ${employeeRepo.latestRecords.length}');
      
      final saleOrderRepo = getIt<SaleOrderRepository>();
      await saleOrderRepo.loadRecords();
      print('   Sale Orders totales: ${saleOrderRepo.latestRecords.length}');
      
      // Test 5: Verificar marcadores actualizados
      print('\n🔍 TEST 5: Marcadores actualizados:');
      final newMarkers = markerStore.getAllMarkers();
      for (final entry in newMarkers.entries) {
        print('   ${entry.key}: ${entry.value}');
      }
      
      print('\n🧪 ===== TESTS COMPLETADOS =====');
      
      // Mostrar dialog con resultados
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tests Completados ✅'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Incremental Sync:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('• Fetched: ${result.totalRecordsFetched}'),
                  Text('• Merged: ${result.totalRecordsMerged}'),
                  Text('• Tiempo: ${duration.inSeconds}s'),
                  const SizedBox(height: 16),
                  Text('Conteos Actuales:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('• Partners: ${partnerRepo.latestRecords.length}'),
                  Text('• Products: ${productRepo.latestRecords.length}'),
                  Text('• Employees: ${employeeRepo.latestRecords.length}'),
                  Text('• Sale Orders: ${saleOrderRepo.latestRecords.length}'),
                  const SizedBox(height: 16),
                  const Text('💡 Revisa los logs en la consola para más detalles.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ ERROR EN TESTS: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error en Tests'),
            content: Text('Ocurrió un error:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Tooltip del FAB eliminado al migrar a MotionTabBar
}

