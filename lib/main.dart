import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/cache/custom_odoo_kv.dart';
import 'core/di/injection_container.dart';
import 'data/repositories/partner_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/sale_order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/partner_bloc.dart';
import 'presentation/bloc/partner_event.dart';
import 'presentation/bloc/employee/employee_bloc.dart';
import 'presentation/bloc/employee/employee_event.dart';
import 'presentation/bloc/sale_order/sale_order_bloc.dart';
import 'presentation/bloc/sale_order/sale_order_event.dart';
import 'presentation/bloc/product/product_bloc.dart';
import 'presentation/bloc/product/product_event.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/splash_page.dart';
import "presentation/theme.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Hive para cache
  await Hive.initFlutter();
  
  // Configurar dependencias base (sin autenticación)
  await init();
  
  // Inicializar cache personalizado
  final cache = getIt<CustomOdooKv>();
  await cache.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Odoo Test App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      //darkTheme: AppTheme.dark,
      home: BlocProvider(
        create: (context) => AuthBloc()..add(CheckAuthStatus()),
        child: const AuthWrapper(),
      ),
    );
  }
}

/// Widget que maneja la navegación basada en el estado de autenticación
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const SplashPage();
        } else if (state is AuthAuthenticated) {
          // Crear múltiples BLoCs si estamos autenticados y tenemos los repositories
          try {
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => PartnerBloc(getIt<PartnerRepository>())
                    ..add(LoadPartners()),
                ),
                BlocProvider(
                  create: (context) => EmployeeBloc(getIt<EmployeeRepository>())
                    ..add(LoadEmployees()),
                ),
                BlocProvider(
                  create: (context) =>
                      SaleOrderBloc(getIt<SaleOrderRepository>())
                        ..add(LoadSaleOrders()),
                ),
                BlocProvider(
                  create: (context) => ProductBloc(getIt<ProductRepository>())
                    ..add(LoadProducts()),
                ),
              ],
              child: const HomePage(),
            );
          } catch (e) {
            // Si no se puede obtener los repositories, mostrar error
            return LoginPage(errorMessage: 'Error configurando la aplicación: $e');
          }
        } else if (state is AuthError) {
          return LoginPage(errorMessage: state.message);
        } else {
          return const LoginPage();
        }
      },
    );
  }
}


