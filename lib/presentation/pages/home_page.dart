import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/partner_bloc.dart';
import '../bloc/partner_event.dart';
import '../bloc/employee/employee_bloc.dart';
import '../bloc/employee/employee_event.dart';
import '../widgets/partners_list.dart';
import '../widgets/employees_list.dart';
import '../widgets/sale_orders_list.dart';

/// Página principal de la aplicación
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _currentFilter = 'all';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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
          ],
        ),
        actions: [
          // Botón de búsqueda
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          // Menú de filtros
          PopupMenuButton<String>(
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
          ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final currentIndex = _tabController.index;
          if (currentIndex == 0) {
            _showCreatePartnerDialog();
          } else {
            _showCreateEmployeeDialog();
          }
        },
        tooltip: _tabController.index == 0 ? 'Crear Partner' : 'Crear Empleado',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Maneja la selección de filtros
  void _handleFilterSelection(String filter) {
    setState(() {
      _currentFilter = filter;
    });

    switch (filter) {
      case 'all':
        context.read<PartnerBloc>().add(LoadPartners());
        break;
      case 'customers':
        // Por ahora usar RefreshPartners hasta implementar filtros específicos
        context.read<PartnerBloc>().add(RefreshPartners());
        break;
      case 'suppliers':
        // Por ahora usar RefreshPartners hasta implementar filtros específicos
        context.read<PartnerBloc>().add(RefreshPartners());
        break;
      case 'companies':
        // Por ahora usar RefreshPartners hasta implementar filtros específicos
        context.read<PartnerBloc>().add(RefreshPartners());
        break;
    }
  }

  /// Muestra el diálogo de búsqueda
  void _showSearchDialog() {
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
  }

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
}
