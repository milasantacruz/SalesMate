**Proyecto:** Sistema de Pedidos Mobile con Integración Odoo  
**Fecha:** Septiembre 11, 2025

## **RESUMEN EJECUTIVO:**

Desarrollo de aplicación Flutter para dispositivos móviles que integre la gestión completa de pedidos con Odoo ERP. Incluye configuración automática de dispositivos, autenticación de empleados, creación/edición de pedidos, sincronización bidireccional y funcionalidad offline completa.

**Tecnologías:** Flutter, Dart, BLoC, Hive, Odoo Repository, GetIt, REST APIs  
**Plataforma:** Android/iOS  
**Duración estimada:** 18-22 semanas  
**Endpoints a integrar:** 15 endpoints críticos + API Webadmin  

---

## **ESTIMACIÓN DE HORAS ACTUALIZADA:**

| **Fase** | **Endpoint/Funcionalidad** | **Horas Estimadas** | **Días (8h/día)** |
|----------|---------------------------|---------------------|-------------------|

### **FASE 1 - CRÍTICA (ALTA PRIORIDAD)**
| | | **Total: 280-320h** | **35-40 días** |
|----------|---------------------------|---------------------|-------------------|
| **Configuración Dispositivo** | `GET /api/device/{id}` | 60-70 horas | 8-9 días |
| **Login Empleado** | `hr.employee.search_read` | 30-40 horas | 4-5 días |
| **Dashboard Pedidos** | `sale.order.search_read` | 50-60 horas | 6-8 días |
| **Modelo Sale Order** | `sale.order` (CRUD completo) | 60-70 horas | 8-9 días |
| **Session Management** | `/web/session/authenticate` | 40-50 horas | 5-6 días |
| **Base Arquitectura** | BLoC + Repository setup | 40-30 horas | 4-3 días |

### **FASE 2 - FUNCIONALIDADES CORE (MEDIA PRIORIDAD)**
| | | **Total: 320-400h** | **40-50 días** |
|----------|---------------------------|---------------------|-------------------|
| **Selección Cliente** | `res.partner.search_read` | 60-80 horas | 8-10 días |
| **Gestión Direcciones** | `res.partner.create/write` | 40-50 horas | 5-6 días |
| **Búsqueda Productos** | `product.product.search_read` | 70-90 horas | 9-11 días |
| **Cálculo Precios** | `product.pricelist` | 80-100 horas | 10-13 días |
| **Líneas de Pedido** | `sale.order.line` (CRUD) | 70-80 horas | 9-10 días |

### **FASE 3 - SINCRONIZACIÓN Y AVANZADO (BAJA PRIORIDAD)**
| | | **Total: 240-320h** | **30-40 días** |
|----------|---------------------------|---------------------|-------------------|
| **Sync Bidireccional** | Multiple endpoints | 100-120 horas | 13-15 días |
| **Cola Offline** | Hive + Background sync | 60-80 horas | 8-10 días |
| **Manejo Conflictos** | Logic + UI | 40-60 horas | 5-8 días |
| **Impuestos y Totales** | `account.tax` | 40-60 horas | 5-8 días |

### **FASE 4 - TESTING Y PULIMIENTO**
| | | **Total: 160-200h** | **20-25 días** |
|----------|---------------------------|---------------------|-------------------|
| **Testing Integral** | Unit + Integration tests | 80-100 horas | 10-13 días |
| **UI/UX Refinamiento** | Polish + Responsive | 50-60 horas | 6-8 días |
| **Performance** | Optimizaciones | 30-40 horas | 4-5 días |

---

## **TOTAL GENERAL: 1000-1240 horas (125-155 días laborales)**

---

## **PROPUESTA: CONTRATO POR PROYECTO**

### **SERVICIO OFRECIDO:**
Desarrollo completo de aplicación Flutter para gestión de pedidos con integración completa a Odoo ERP y API Webadmin.

### **MODALIDAD:**
- **Contrato por proyecto:** Precio fijo con hitos de pago
- **Jornada:** 8 horas diarias, Lunes a Viernes
- **Duración estimada:** 18-22 semanas laborales

---

## **CRONOGRAMA:**

| **Fase** | **Duración** | **Descripción** |
|----------|--------------|-----------------|
| **Desarrollo Fase 1** | 7-8 semanas | Configuración + Login + Dashboard básico |
| **Desarrollo Fase 2** | 8-10 semanas | Funcionalidades core de pedidos |
| **Desarrollo Fase 3** | 6-8 semanas | Sincronización y funcionalidades avanzadas |
| **Testing y Pulimiento** | 3-4 semanas | Pruebas integrales y optimizaciones |

---

## **ALCANCE:**

### ✅ **INCLUIDO:**
- UI/UX moderna con Material Design 3
- Base de datos local con Hive
- Arquitectura BLoC + Repository Pattern
- Funcionalidad offline completa
- Sincronización bidireccional automática
- Integración con 15+ endpoints Odoo
- Integración con API Webadmin
- Manejo robusto de errores
- Testing integral (Unit + Integration)
- Documentación técnica
- Manual de usuario

### ❌ **NO INCLUIDO:**
- Desarrollo de APIs backend
- Configuración servidor Odoo
- Mantenimiento post-entrega
- Capacitaciones presenciales
- Modificaciones a modelos Odoo existentes

---

## **HITOS DE PAGO:**

| **Hito** | **Entregable** | **% Pago** | **Monto** |
|----------|----------------|------------|-----------|
| **Inicio** | Contrato firmado | 20% | $X,XXX USD |
| **Hito 1** | Login + Dashboard funcional | 25% | $X,XXX USD |
| **Hito 2** | CRUD Pedidos completo | 25% | $X,XXX USD |
| **Hito 3** | Sincronización implementada | 20% | $X,XXX USD |
| **Entrega Final** | App completa + Testing | 10% | $X,XXX USD |

---

## **INVERSIÓN TOTAL:**
**$XX,XXX - $XX,XXX USD**  
*(Precio final según alcance definitivo y complejidad de integraciones)*

---

## **ENTREGABLES:**

1. **Aplicación Flutter** completa y funcional
2. **Código fuente** comentado y documentado
3. **Manual técnico** de instalación y configuración
4. **Manual de usuario** con capturas de pantalla
5. **Documentación de APIs** integradas
6. **Suite de testing** automatizada

---

## **DEPENDENCIAS CRÍTICAS:**

### 🚨 **BLOQUEANTES ACTUALES:**
1. **Session ID Backend** - Configuración `/web/session/authenticate`
2. **API Webadmin** - Documentación y acceso
3. **Servidor Odoo Staging** - Ambiente de desarrollo

### ⚠️ **RIESGOS IDENTIFICADOS:**
1. **Cambios en modelos Odoo** durante desarrollo
2. **Complejidad algoritmos pricing** no documentados
3. **Performance con grandes volúmenes** de datos

---

*Estimación basada en arquitectura Flutter BLoC + Odoo Repository ya implementada. Tiempos pueden variar según disponibilidad de APIs y claridad de requerimientos.*