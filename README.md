# 📱 Sistema de Pedidos Mobile - Odoo Integration

Aplicación Flutter para gestión de pedidos con integración completa a Odoo ERP. Diseñada para dispositivos móviles con funcionalidad offline y sincronización bidireccional.

## 🚀 Características Principales

- **🔧 Configuración Automática**: Auto-configuración mediante API Webadmin
- **🔐 Autenticación Empleados**: Login con usuario y PIN
- **📊 Dashboard Intuitivo**: Filtrado de pedidos por estado (Borrador/Enviado/Confirmado)
- **👥 Gestión de Clientes**: Búsqueda por RUT/nombre con direcciones múltiples
- **📦 Catálogo de Productos**: Búsqueda por SKU, código de barras o nombre
- **💰 Cálculo Automático**: Precios basados en tarifas de cliente e impuestos
- **🔄 Sincronización**: Bidireccional automática y manual
- **📴 Modo Offline**: Funcionalidad completa sin conexión

## 🏗️ Arquitectura Técnica

### **Stack Tecnológico**
- **Framework**: Flutter 3.8+
- **Lenguaje**: Dart
- **State Management**: BLoC Pattern
- **Dependency Injection**: GetIt
- **Cache Local**: Hive
- **HTTP Client**: Odoo Repository + RPC

### **Estructura del Proyecto**
```
lib/
├── core/
│   ├── constants/        # Configuraciones y constantes
│   ├── di/              # Inyección de dependencias
│   ├── network/         # Conectividad y manejo de red
│   └── cache/           # Cache local personalizado
├── data/
│   ├── models/          # Modelos de datos Odoo
│   └── repositories/    # Repositorios de acceso a datos
├── presentation/
│   ├── bloc/           # Estado de la aplicación
│   ├── pages/          # Pantallas principales
│   └── widgets/        # Componentes reutilizables
└── main.dart
```

## 🔗 Integraciones API

### **Endpoints Odoo**
- `sale.order` - Gestión completa de pedidos
- `res.partner` - Clientes y direcciones
- `product.product` - Catálogo de productos
- `product.pricelist` - Cálculo de precios
- `hr.employee` - Autenticación empleados
- `account.tax` - Manejo de impuestos

### **API Webadmin**
- `GET /api/device/{id}` - Configuración dispositivo
- `GET /api/device/{id}/status` - Estado del dispositivo

## 🛠️ Configuración de Desarrollo

### **Prerrequisitos**
- Flutter SDK 3.8.1+
- Dart 3.0+
- Android Studio / VS Code
- Servidor Odoo con acceso RPC

### **Instalación**
```bash
# Clonar repositorio
git clone [repository-url]
cd odoo_test

# Instalar dependencias
flutter pub get

# Ejecutar aplicación
flutter run
```

### **Configuración Inicial**
1. Configurar constantes en `lib/core/constants/app_constants.dart`
2. Ajustar URL del servidor Odoo
3. Configurar credenciales de prueba (desarrollo)

## 📊 Estado del Proyecto

### **✅ Implementado**
- Arquitectura base (BLoC + Repository)
- Inyección de dependencias (GetIt)
- Cache local (Hive)
- Conectividad de red
- Autenticación básica
- Repository de Partners

### **🚧 En Desarrollo**
- Dashboard de pedidos
- CRUD completo de pedidos
- Gestión de productos y precios
- Sincronización bidireccional

### **📋 Pendiente**
- UI/UX completa
- Testing integral
- Optimizaciones de performance
- Documentación de usuario

## 🔧 Scripts Útiles

```bash
# Ejecutar tests
flutter test

# Generar build
flutter build apk

# Limpiar proyecto
flutter clean && flutter pub get

# Analizar código
flutter analyze
```

## 📚 Documentación Adicional

- [`Docx/auth-implementation-checklist.md`](Docx/auth-implementation-checklist.md) - Checklist de autenticación
- [`Docx/estimacion-desarrollo-app.md`](Docx/estimacion-desarrollo-app.md) - Estimación de desarrollo
- [`Docx/Arquitectura.md`](Docx/Arquitectura.md) - Documentación de arquitectura

## 🤝 Contribución

Este es un proyecto privado en desarrollo. Para contribuir:

1. Crear branch feature desde `develop`
2. Implementar cambios con tests
3. Crear Pull Request con descripción detallada

## 📄 Licencia

Proyecto privado - Todos los derechos reservados

---

**Desarrollado con ❤️ usando Flutter y Odoo**
