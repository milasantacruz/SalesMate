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
              BlocProvider(
                create: (context) => PartnerBloc(getIt<PartnerRepository>())
                  ..add(LoadPartners()),
              ),
              BlocProvider(
                create: (context) =>
                    SaleOrderBloc(getIt<SaleOrderRepository>())
                      ..add(LoadSaleOrders()),
              ),
              BlocProvider(
                create: (context) => ProductBloc(
                  getIt<ProductRepository>(),
                  getIt<PricelistRepository>(),
                )..add(LoadProducts()),
              ),
              BlocProvider(
                create: (context) => EmployeeBloc(getIt<EmployeeRepository>())
                  ..add(LoadEmployees()),
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
            return const HomePage();
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