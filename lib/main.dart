import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/cache/custom_odoo_kv.dart';
import 'core/di/injection_container.dart';
import 'data/repositories/partner_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/sale_order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/pricelist_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/partner_bloc.dart';
import 'presentation/bloc/partner_event.dart';
import 'presentation/bloc/sale_order/sale_order_bloc.dart';
import 'presentation/bloc/sale_order/sale_order_event.dart';
import 'presentation/bloc/product/product_bloc.dart';
import 'presentation/bloc/product/product_event.dart';
import 'presentation/bloc/employee/employee_bloc.dart';
import 'presentation/bloc/employee/employee_event.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/pages/license_page.dart';
import 'presentation/pages/pin_login_page.dart';
import "presentation/theme.dart";
import 'presentation/bloc/bootstrap/bootstrap_bloc.dart';
import 'presentation/bloc/bootstrap/bootstrap_event.dart';
import 'presentation/bloc/bootstrap/bootstrap_state.dart';
import 'core/bootstrap/bootstrap_state.dart' as core;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Hive para cache
  await Hive.initFlutter();
  
  // Configurar dependencias base (sin autenticación)
  await init();
  
  // Inicializar cache personalizado
  final cache = getIt<CustomOdooKv>();
  await cache.init();
  
  runApp(
    BlocProvider(
      create: (context) => AuthBloc()..add(CheckAuthStatus()),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Usamos un MultiBlocProvider aquí para que esté disponible en todo el árbol de MaterialApp
        return MultiBlocProvider(
          providers: [
            // Mantenemos el AuthBloc que ya está siendo provisto
            BlocProvider.value(value: BlocProvider.of<AuthBloc>(context)),
            // Proveemos los demás BLoCs solo si el usuario está autenticado
            if (authState is AuthAuthenticated) ...[
              // Bootstrap de caché al autenticar
              BlocProvider(
                create: (context) => BootstrapBloc()..add(BootstrapStarted()),
              ),
              BlocProvider(
                create: (context) => PartnerBloc(getIt<PartnerRepository>()),
              ),
              BlocProvider(
                create: (context) => SaleOrderBloc(getIt<SaleOrderRepository>()),
              ),
              BlocProvider(
                create: (context) => ProductBloc(
                  getIt<ProductRepository>(),
                  getIt<PricelistRepository>(),
                ),
              ),
              BlocProvider(
                create: (context) => EmployeeBloc(getIt<EmployeeRepository>()),
              ),
            ],
          ],
          child: MaterialApp(
            title: 'SalesMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const AuthWrapper(),
            routes: {
              '/license': (context) => const LicenseValidationPage(),
              '/pin-login': (context) => const PinLoginPage(),
              '/home': (context) => const HomePage(),
              '/login': (context) => const LoginPage(),
            },
          ),
        );
      },
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final core.ModuleBootstrapStatus? status;
  const _ProgressRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final isError = status?.errorMessage != null;
    final isCompleted = status?.completed == true;
    final isLoading = status?.recordsFetched != null && status!.recordsFetched > 0 && !isCompleted;
    
    String text;
    Color textColor;
    
    if (status == null) {
      text = 'Waiting...';
      textColor = Colors.grey;
    } else if (isError) {
      text = 'Error';
      textColor = Colors.red;
    } else if (isCompleted) {
      text = 'Done (${status!.recordsFetched})';
      textColor = Colors.green;
    } else if (isLoading) {
      text = 'Loading (${status!.recordsFetched})';
      textColor = Colors.blue;
    } else {
      text = 'Pending';
      textColor = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Widget que maneja la navegación basada en el estado de autenticación
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Mostrar mensaje cuando la sesión expira
        if (state is AuthUnauthenticated) {
          print('🚨 AUTH_WRAPPER: Sesión expirada - mostrando mensaje');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesión expirada. Por favor, inicia sesión nuevamente.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          print('🏠 AUTH_WRAPPER: Estado actual: ${state.runtimeType}');
          
          if (state is AuthLoading) {
            return const SplashPage();
          } else if (state is AuthAuthenticated) {
            // Crear los BLoCs SIEMPRE que esté autenticado
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => PartnerBloc(getIt<PartnerRepository>()),
                ),
                BlocProvider(
                  create: (context) => SaleOrderBloc(getIt<SaleOrderRepository>()),
                ),
                BlocProvider(
                  create: (context) => ProductBloc(
                    getIt<ProductRepository>(),
                    getIt<PricelistRepository>(),
                  ),
                ),
                BlocProvider(
                  create: (context) => EmployeeBloc(getIt<EmployeeRepository>()),
                ),
              ],
              child: BlocListener<BootstrapBloc, UiBootstrapState>(
                listener: (context, bState) {
                  // Cargar datos SOLO cuando bootstrap completa
                  if (bState is UiBootstrapCompleted) {
                    print('🎯 MAIN: Bootstrap completado, cargando datos en BLoCs...');
                    context.read<PartnerBloc>().add(LoadPartners());
                    context.read<SaleOrderBloc>().add(LoadSaleOrders());
                    context.read<ProductBloc>().add(LoadProducts());
                    context.read<EmployeeBloc>().add(LoadEmployees());
                  }
                },
                child: BlocBuilder<BootstrapBloc, UiBootstrapState>(
                  builder: (context, bState) {
                    // Si el bootstrap está completado, mostrar HomePage
                    if (bState is UiBootstrapCompleted) {
                      return const HomePage();
                    }
                    
                    // Si el bootstrap está en progreso, mostrar SOLO el overlay (sin HomePage)
                    if (bState is UiBootstrapInProgress) {
                      final progress = (bState.state.totalProgress * 100).toStringAsFixed(0);
                      final modules = bState.state.modules;
                      final partners = modules[core.BootstrapModule.partners];
                      final products = modules[core.BootstrapModule.products];
                      final employees = modules[core.BootstrapModule.employees];
                      final saleOrders = modules[core.BootstrapModule.saleOrders];
                      return Scaffold(
                        body: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: SafeArea(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Preparing offline data',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              // Cerrar el overlay manualmente
                                              context.read<BootstrapBloc>().add(BootstrapDismissed());
                                            },
                                            icon: const Icon(Icons.close, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(value: bState.state.totalProgress == 0 ? null : bState.state.totalProgress),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('$progress% completed', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                      _ProgressRow(label: 'Partners', status: partners),
                                      _ProgressRow(label: 'Products', status: products),
                                      _ProgressRow(label: 'Employees', status: employees),
                                      _ProgressRow(label: 'Sale Orders', status: saleOrders),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    // Estado inicial o cualquier otro estado
                    return const SplashPage();
                  },
                ),
              ),
            );
          } else if (state is AuthLicenseValidated) {
            // Después de validar licencia, ir a PIN login
            return const PinLoginPage();
          } else if (state is AuthError || state is AuthUnauthenticated || state is AuthInitial) {
            // Si hay error, no autenticado, o estado inicial → mostrar licencia
            // El error se mostrará dentro de LicenseValidationPage
            return const LicenseValidationPage();
          } else {
            // Fallback: mostrar pantalla de licencia
            return const LicenseValidationPage();
          }
        },
      ),
    );
  }
}