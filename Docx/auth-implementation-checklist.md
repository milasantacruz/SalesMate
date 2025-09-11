# 🔐 Checklist: Implementación de Sistema de Autenticación

## 📋 **Resumen**
Migrar de login automático con credenciales hardcodeadas a sistema de autenticación por interfaz con login dinámico.

## 🚨 **ESTADO ACTUAL - BLOQUEADO POR BACKEND**

**✅ COMPLETADO**: Sistema de autenticación Flutter implementado correctamente
**❌ BLOQUEADO**: Servidor Odoo no retorna `session_id` válido
**🎯 ACCIÓN REQUERIDA**: Configurar `/web/session/authenticate` en servidor staging

### **Problema Identificado**
- El login funciona (HTTP 200 OK, uid: 2)
- El servidor NO incluye `session_id` en la respuesta JSON
- Las llamadas RPC posteriores fallan con "Session Expired"
- **SOLUCIÓN**: Backend debe configurar session management

---

## 🎯 **FASE 1: Estructura Base de Autenticación**

### **1.1 Crear AuthBloc Structure**
- [ ] **Crear directorio**: `lib/presentation/bloc/auth/`
- [ ] **Crear archivo**: `lib/presentation/bloc/auth/auth_event.dart`
  ```dart
  abstract class AuthEvent extends Equatable {
    const AuthEvent();
    @override
    List<Object> get props => [];
  }
  
  class CheckAuthStatus extends AuthEvent {}
  
  class LoginRequested extends AuthEvent {
    final String username;
    final String password;
    final String? serverUrl;
    final String? database;
    
    const LoginRequested({
      required this.username,
      required this.password,
      this.serverUrl,
      this.database,
    });
    
    @override
    List<Object> get props => [username, password, serverUrl ?? '', database ?? ''];
  }
  
  class LogoutRequested extends AuthEvent {}
  ```

- [ ] **Crear archivo**: `lib/presentation/bloc/auth/auth_state.dart`
  ```dart
  abstract class AuthState extends Equatable {
    const AuthState();
    @override
    List<Object> get props => [];
  }
  
  class AuthInitial extends AuthState {}
  
  class AuthLoading extends AuthState {}
  
  class AuthAuthenticated extends AuthState {
    final String username;
    final String userId;
    final String database;
    
    const AuthAuthenticated({
      required this.username,
      required this.userId,
      required this.database,
    });
    
    @override
    List<Object> get props => [username, userId, database];
  }
  
  class AuthUnauthenticated extends AuthState {}
  
  class AuthError extends AuthState {
    final String message;
    final String? details;
    
    const AuthError(this.message, {this.details});
    
    @override
    List<Object> get props => [message, details ?? ''];
  }
  ```

- [ ] **Crear archivo**: `lib/presentation/bloc/auth/auth_bloc.dart`
  ```dart
  class AuthBloc extends Bloc<AuthEvent, AuthState> {
    AuthBloc() : super(AuthInitial()) {
      on<CheckAuthStatus>(_onCheckAuthStatus);
      on<LoginRequested>(_onLoginRequested);
      on<LogoutRequested>(_onLogoutRequested);
    }
    
    Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
      // Implementar verificación de sesión existente
    }
    
    Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
      // Implementar lógica de login
    }
    
    Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
      // Implementar lógica de logout
    }
  }
  ```

### **1.2 Crear LoginPage**
- [ ] **Crear archivo**: `lib/presentation/pages/login_page.dart`
- [ ] **Implementar form fields**:
  - [ ] Campo username (required)
  - [ ] Campo password (required, obscured)
  - [ ] Campo server URL (opcional, con valor por defecto)
  - [ ] Campo database (opcional, con valor por defecto)
- [ ] **Implementar validaciones**:
  - [ ] Username no vacío
  - [ ] Password mínimo 6 caracteres
  - [ ] Server URL formato válido (si se proporciona)
- [ ] **Implementar UI states**:
  - [ ] Loading spinner durante login
  - [ ] Error messages
  - [ ] Success feedback
- [ ] **Conectar con AuthBloc**:
  - [ ] BlocListener para navegación
  - [ ] BlocBuilder para UI states

### **1.3 Crear SplashPage (Opcional)**
- [ ] **Crear archivo**: `lib/presentation/pages/splash_page.dart`
- [ ] **Implementar**:
  - [ ] Logo de la app
  - [ ] Loading indicator
  - [ ] Auto-navegación basada en auth status

---

## 🔧 **FASE 2: Modificar Injection Container**

### **2.1 Separar Login de Inicialización**
- [ ] **Modificar `lib/core/di/injection_container.dart`**:
  - [ ] **Remover** `setupOdooEnvironment()` de `init()`
  - [ ] **Mantener solo** registro de dependencias base en `init()`
  - [ ] **Crear** función `loginWithCredentials()` que reciba parámetros

- [ ] **Nueva función `loginWithCredentials()`**:
  ```dart
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
    String? serverUrl,
    String? database,
  }) async {
    try {
      // Actualizar constants dinámicamente si es necesario
      final client = getIt<OdooClient>();
      final cache = getIt<CustomOdooKv>();
      
      final session = await client.authenticate(
        database ?? AppConstants.odooDbName,
        username,
        password,
      );
      
      if (session != null) {
        await cache.put(AppConstants.cacheSessionKey, session.id.toString());
        await _recreateClientWithSession(session);
        await _recreateOdooEnvironment();
        await _setupRepositories();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error en login: $e');
      return false;
    }
  }
  ```

- [ ] **Crear función `_setupRepositories()`**:
  ```dart
  Future<void> _setupRepositories() async {
    final env = getIt<OdooEnvironment>();
    final partnerRepo = env.add(PartnerRepository(env));
    
    if (getIt.isRegistered<PartnerRepository>()) {
      getIt.unregister<PartnerRepository>();
    }
    getIt.registerLazySingleton<PartnerRepository>(() => partnerRepo);
  }
  ```

### **2.2 Función de Logout**
- [ ] **Crear función `logout()`**:
  ```dart
  Future<void> logout() async {
    try {
      final cache = getIt<CustomOdooKv>();
      
      // Limpiar cache
      await cache.delete(AppConstants.cacheSessionKey);
      
      // Desregistrar dependencias que requieren autenticación
      if (getIt.isRegistered<PartnerRepository>()) {
        getIt.unregister<PartnerRepository>();
      }
      if (getIt.isRegistered<OdooEnvironment>()) {
        getIt.unregister<OdooEnvironment>();
      }
      if (getIt.isRegistered<OdooClient>()) {
        getIt.unregister<OdooClient>();
      }
      
      // Recrear cliente sin sesión
      getIt.registerLazySingleton<OdooClient>(
        () => OdooClient(AppConstants.odooServerURL),
      );
      
      print('✅ Logout completado');
    } catch (e) {
      print('❌ Error en logout: $e');
    }
  }
  ```

### **2.3 Función de Verificación de Sesión**
- [ ] **Crear función `checkExistingSession()`**:
  ```dart
  Future<bool> checkExistingSession() async {
    try {
      final cache = getIt<CustomOdooKv>();
      final sessionId = cache.get(AppConstants.cacheSessionKey);
      
      if (sessionId != null) {
        // Verificar si la sesión sigue válida
        final client = getIt<OdooClient>();
        // TODO: Implementar verificación de sesión válida
        return true; // Por ahora asumir válida
      }
      return false;
    } catch (e) {
      print('❌ Error verificando sesión: $e');
      return false;
    }
  }
  ```

---

## 🔗 **FASE 3: Integrar AuthBloc**

### **3.1 Implementar Lógica del AuthBloc**
- [ ] **Completar `_onCheckAuthStatus()`**:
  ```dart
  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      final hasValidSession = await checkExistingSession();
      if (hasValidSession) {
        // TODO: Obtener datos del usuario desde cache
        emit(AuthAuthenticated(
          username: 'cached_user', // Obtener del cache
          userId: 'cached_id',
          database: AppConstants.odooDbName,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Error verificando autenticación: $e'));
    }
  }
  ```

- [ ] **Completar `_onLoginRequested()`**:
  ```dart
  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      final success = await loginWithCredentials(
        username: event.username,
        password: event.password,
        serverUrl: event.serverUrl,
        database: event.database,
      );
      
      if (success) {
        // Guardar datos del usuario
        final cache = getIt<CustomOdooKv>();
        await cache.put('username', event.username);
        await cache.put('database', event.database ?? AppConstants.odooDbName);
        
        emit(AuthAuthenticated(
          username: event.username,
          userId: 'user_id', // Obtener del resultado del login
          database: event.database ?? AppConstants.odooDbName,
        ));
      } else {
        emit(AuthError('Credenciales inválidas'));
      }
    } catch (e) {
      emit(AuthError('Error de conexión: $e'));
    }
  }
  ```

- [ ] **Completar `_onLogoutRequested()`**:
  ```dart
  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      await logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Error en logout: $e'));
    }
  }
  ```

---

## 📱 **FASE 4: Modificar Navegación Principal**

### **4.1 Actualizar main.dart**
- [ ] **Modificar función `main()`**:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await init(); // Solo DI, SIN setupOdooEnvironment
    final cache = getIt<CustomOdooKv>();
    await cache.init();
    runApp(const MyApp());
  }
  ```

### **4.2 Modificar MyApp Widget**
- [ ] **Actualizar `MyApp` class**:
  ```dart
  class MyApp extends StatelessWidget {
    const MyApp({super.key});
    
    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Odoo Test App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // ... existing theme
        ),
        home: BlocProvider(
          create: (context) => AuthBloc()..add(CheckAuthStatus()),
          child: const AuthWrapper(),
        ),
      );
    }
  }
  ```

### **4.3 Crear AuthWrapper Widget**
- [ ] **Crear `AuthWrapper` en main.dart**:
  ```dart
  class AuthWrapper extends StatelessWidget {
    const AuthWrapper({super.key});
    
    @override
    Widget build(BuildContext context) {
      return BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading) {
            return const SplashPage(); // O loading widget
          } else if (state is AuthAuthenticated) {
            return BlocProvider(
              create: (context) => PartnerBloc(getIt<PartnerRepository>()),
              child: const HomePage(),
            );
          } else if (state is AuthError) {
            return LoginPage(errorMessage: state.message);
          } else {
            return const LoginPage();
          }
        },
      );
    }
  }
  ```

---

## 🎨 **FASE 5: Implementar UI del LoginPage**

### **5.1 Estructura Básica**
- [ ] **Implementar layout del LoginPage**:
  - [ ] AppBar con título
  - [ ] Form con GlobalKey
  - [ ] Card container para campos
  - [ ] Botón de login
  - [ ] Loading overlay

### **5.2 Form Fields**
- [ ] **Campo Username**:
  ```dart
  TextFormField(
    controller: _usernameController,
    decoration: InputDecoration(
      labelText: 'Usuario',
      prefixIcon: Icon(Icons.person),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Usuario requerido';
      }
      return null;
    },
  )
  ```

- [ ] **Campo Password**:
  ```dart
  TextFormField(
    controller: _passwordController,
    obscureText: _obscurePassword,
    decoration: InputDecoration(
      labelText: 'Contraseña',
      prefixIcon: Icon(Icons.lock),
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Contraseña requerida';
      }
      if (value.length < 6) {
        return 'Contraseña debe tener al menos 6 caracteres';
      }
      return null;
    },
  )
  ```

### **5.3 Configuración Avanzada (Expandible)**
- [ ] **ExpansionTile para configuración**:
  - [ ] Campo Server URL (con valor por defecto)
  - [ ] Campo Database (con valor por defecto)
  - [ ] Switch "Recordar configuración"

### **5.4 BLoC Integration**
- [ ] **BlocListener para navegación**:
  ```dart
  BlocListener<AuthBloc, AuthState>(
    listener: (context, state) {
      if (state is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message)),
        );
      }
    },
    child: // ... UI
  )
  ```

- [ ] **BlocBuilder para estados**:
  ```dart
  BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      return Stack(
        children: [
          // Form UI
          if (state is AuthLoading)
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    },
  )
  ```

---

## 🏠 **FASE 6: Actualizar HomePage**

### **6.1 Agregar AppBar Actions**
- [ ] **Agregar botón de logout en HomePage**:
  ```dart
  AppBar(
    title: Text('Partners'),
    actions: [
      BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Text('Perfil (${state.username})'),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar Sesión'),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  context.read<AuthBloc>().add(LogoutRequested());
                }
              },
            );
          }
          return SizedBox.shrink();
        },
      ),
    ],
  )
  ```

---

## ✅ **FASE 7: Testing y Validación**

### **7.1 Tests Unitarios**
- [ ] **Crear tests para AuthBloc**:
  - [ ] Test login exitoso
  - [ ] Test login fallido
  - [ ] Test logout
  - [ ] Test verificación de sesión

### **7.2 Tests de Widget**
- [ ] **Test LoginPage**:
  - [ ] Validación de campos
  - [ ] Submit del form
  - [ ] Estados de loading

### **7.3 Tests de Integración**
- [ ] **Test flujo completo**:
  - [ ] Splash → Login → Home
  - [ ] Logout → Login
  - [ ] Persistencia de sesión

---

## 🔧 **FASE 8: Mejoras Opcionales**

### **8.1 Remember Me**
- [ ] **Checkbox "Recordar credenciales"**
- [ ] **Persistir username (NO password)**
- [ ] **Auto-fill en próximo login**

### **8.2 Configuración Dinámica**
- [ ] **Permitir cambiar servidor**
- [ ] **Permitir cambiar base de datos**
- [ ] **Validar conectividad antes del login**

### **8.3 Biometrics (Futuro)**
- [ ] **Integrar local_auth**
- [ ] **Login con huella/face**
- [ ] **Fallback a credenciales**

---

## 📊 **Checklist de Validación Final**

- [ ] **✅ Login funciona con credenciales válidas**
- [ ] **✅ Login falla con credenciales inválidas**
- [ ] **✅ Logout limpia sesión correctamente**
- [ ] **✅ Persistencia de sesión entre reinicios**
- [ ] **✅ UI responsive en diferentes tamaños**
- [ ] **✅ Error handling robusto**
- [ ] **✅ Loading states apropiados**
- [ ] **✅ Navegación fluida**
- [ ] **✅ No hay memory leaks**
- [ ] **✅ Performance aceptable**

---

## 🎯 **Notas Importantes**

### **Seguridad:**
- ❌ **NO persistir passwords en texto plano**
- ✅ **Solo persistir session tokens**
- ✅ **Limpiar datos sensibles en logout**

### **UX:**
- ✅ **Feedback visual claro**
- ✅ **Validaciones en tiempo real**
- ✅ **Mensajes de error descriptivos**

### **Performance:**
- ✅ **Lazy loading de dependencias**
- ✅ **Dispose controllers apropiadamente**
- ✅ **Optimizar rebuilds innecesarios**

---

**Total Estimado:** 2-3 días de desarrollo + 1 día testing
**Prioridad:** Alta (mejora significativa de UX y seguridad)
