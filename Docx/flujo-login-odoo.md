# 🔐 Diagrama de Flujo: Proceso de Login Flutter + Odoo

## 🎯 **Flujo Principal de Autenticación**

```mermaid
flowchart TD
    A["📱 Usuario inicia app"] --> B{"🔍 Verificar sesión existente"}
    B -->|"Sesión válida"| C["✅ Ir a Home"]
    B -->|"Sin sesión"| D["🔐 Mostrar Login Page"]
    
    D --> E["👤 Usuario ingresa credenciales"]
    E --> F["📤 AuthBloc: LoginRequested"]
    F --> G["🔧 Inicializar dependencias"]
    
    G --> H{"🌐 Flutter Web?"}
    H -->|"Sí"| I["🍪 BrowserClient + withCredentials"]
    H -->|"No"| J["📱 HTTP Client estándar"]
    
    I --> K["🔗 OdooClient configurado"]
    J --> K
    
    K --> L["🚀 client.authenticate()"]
    L --> M{"📡 Usar CORS Proxy?"}
    
    M -->|"Sí"| N["🌉 Request a Proxy localhost:8080"]
    M -->|"No"| O["🌐 Request directo a Odoo Server"]
    
    N --> P["🔄 Proxy modifica cookies"]
    O --> Q["📨 Respuesta Odoo"]
    P --> Q
    
    Q --> R{"🔍 Session ID en respuesta?"}
    R -->|"Sí"| S["✅ Session válido"]
    R -->|"No"| T["🔧 WORKAROUND: Extraer de proxy"]
    
    T --> U["🍪 SessionInterceptor extract"]
    U --> V["🔄 Crear OdooSession con ID manual"]
    V --> S
    
    S --> W["💾 Guardar en cache Hive"]
    W --> X["🔄 Recrear OdooEnvironment"]
    X --> Y["📋 Configurar Repositories"]
    Y --> Z["✅ Login exitoso - Home"]
    
    style A fill:#e1f5fe
    style C fill:#c8e6c9
    style D fill:#fff3e0
    style I fill:#f3e5f5
    style T fill:#ffecb3
    style Z fill:#c8e6c9
```

## 🔧 **Flujo Técnico Detallado**

```mermaid
sequenceDiagram
    participant U as Usuario
    participant UI as Flutter UI
    participant AB as AuthBloc
    participant IC as InjectionContainer
    participant OC as OdooClient
    participant P as Proxy Server
    participant O as Odoo Server
    participant SI as SessionInterceptor
    participant H as Hive Cache

    U->>UI: Ingresa credenciales
    UI->>AB: LoginRequested
    AB->>IC: loginWithCredentials()
    
    Note over IC: Verificar plataforma
    IC->>IC: kIsWeb check
    
    Note over IC: Configurar OdooClient
    IC->>OC: new OdooClient
    
    IC->>OC: authenticate()
    
    alt Con CORS Proxy
        OC->>P: POST authenticate
        P->>O: Forward request
        O->>P: Response + cookies
        
        Note over P: Modificar cookies
        P->>P: Remove Secure flag
        P->>P: Change SameSite
        P->>P: Remove Domain
        
        P->>OC: Modified response
    else Directo a Odoo
        OC->>O: POST authenticate
        O->>OC: Response + cookies
    end
    
    OC->>IC: OdooSession empty
    
    Note over IC: Session ID vacio detectado
    IC->>SI: extractSessionFromProxyLogs()
    SI->>SI: Extract hardcoded session
    SI->>IC: return session_id
    
    IC->>IC: Create new OdooSession
    IC->>H: cache session
    
    IC->>IC: recreateOdooEnvironment()
    IC->>IC: setupRepositories()
    
    IC->>AB: return success
    AB->>UI: AuthAuthenticated state
    UI->>U: Navigate to Home
    
    Note over UI: Load Partners
    UI->>UI: PartnersListWidget
```

## 🏗️ **Arquitectura de Componentes**

```mermaid
graph TB
    subgraph FF ["🖥️ Flutter Frontend"]
        LP["🔐 LoginPage"]
        AB["🧠 AuthBloc"]
        HP["🏠 HomePage"]
        PW["📋 PartnersWidget"]
    end
    
    subgraph CS ["⚙️ Core Services"]
        IC["🔧 InjectionContainer"]
        OC["🔗 OdooClient"]
        OE["🌐 OdooEnvironment"]
        PR["📊 PartnerRepository"]
    end
    
    subgraph SL ["💾 Storage Layer"]
        H["🗄️ Hive Cache"]
        SI["🍪 SessionInterceptor"]
    end
    
    subgraph NL ["🌉 Network Layer"]
        P["🌉 CORS Proxy"]
        BC["🍪 BrowserClient"]
    end
    
    subgraph OB ["🏢 Odoo Backend"]
        O["🏢 Odoo Server"]
        DB[("🗃️ PostgreSQL")]
    end
    
    LP --> AB
    AB --> IC
    IC --> OC
    IC --> OE
    IC --> PR
    IC --> H
    IC --> SI
    
    OC --> BC
    BC --> P
    P --> O
    O --> DB
    
    AB --> HP
    HP --> PW
    PW --> PR
    
    style LP fill:#fff3e0
    style AB fill:#e8f5e8
    style IC fill:#f3e5f5
    style P fill:#e1f5fe
    style O fill:#ffecb3
```

## 🔄 **Estados del Sistema**

```mermaid
stateDiagram-v2
    [*] --> AuthInitial
    AuthInitial --> AuthLoading : App Start
    
    AuthLoading --> AuthUnauthenticated : No Session Found
    AuthLoading --> AuthAuthenticated : Valid Session
    
    AuthUnauthenticated --> AuthLoading : Login Attempt
    AuthLoading --> AuthError : Login Failed
    AuthLoading --> AuthAuthenticated : Login Success
    
    AuthAuthenticated --> AuthLoading : Logout
    AuthError --> AuthLoading : Retry Login
    
    state AuthAuthenticated {
        [*] --> LoadingPartners
        LoadingPartners --> PartnersLoaded
        LoadingPartners --> PartnersError
        PartnersError --> LoadingPartners : Retry
    }
```

## 🛠️ **Configuración Crítica**

### **1. 🍪 BrowserClient Configuration**
```dart
// Para Flutter Web - CRÍTICO para cookies
if (kIsWeb) {
  final browserClient = BrowserClient()..withCredentials = true;
  return OdooClient(
    AppConstants.odooServerURL,
    httpClient: browserClient,
    isWebPlatform: true,
  );
}
```

### **2. 🌉 Proxy Cookie Modification**
```javascript
// Modificar cookies para localhost
const modifiedCookies = proxyRes.headers['set-cookie'].map(cookie => {
  return cookie
    .replace(/; Secure/g, '')           // Remove HTTPS requirement
    .replace(/; Domain=[^;]+/g, '')     // Remove domain restriction
    .replace(/; SameSite=Lax/g, '; SameSite=None'); // Allow cross-site
});
```

### **3. 🔧 Session ID Workaround**
```dart
// Extraer session_id manualmente cuando odoo_rpc falla
if (session != null && session.id.isEmpty) {
  SessionInterceptor.extractSessionFromProxyLogs();
  final interceptedSessionId = SessionInterceptor.sessionId;
  
  final fixedSession = OdooSession(
    id: interceptedSessionId,
    // ... otros campos
  );
}
```

## 📊 **Métricas de Performance**

| Paso | Tiempo Estimado | Status |
|------|----------------|--------|
| 🔍 Check Session | ~50ms | ✅ |
| 🔧 Init Dependencies | ~100ms | ✅ |
| 🌐 HTTP Request | ~200-500ms | ✅ |
| 🍪 Cookie Processing | ~10ms | ✅ |
| 🔧 Workaround | ~5ms | ✅ |
| 💾 Cache Storage | ~20ms | ✅ |
| 📋 Load UI | ~100ms | ✅ |
| **Total Login Time** | **~500-800ms** | ✅ |

## 🚨 **Puntos Críticos de Fallo**

1. **🌉 Proxy Server Down** → Login falla
2. **🍪 Cookies Blocked** → Session ID vacío
3. **🔗 CORS Issues** → Request blocked
4. **🏢 Odoo Server Error** → Authentication fails
5. **💾 Cache Corruption** → Session persistence fails

## 🎯 **Mejoras Futuras**

1. **🔄 Auto-refresh** de session_id
2. **🍪 Real cookie interception** (sin hardcoding)
3. **⚡ Connection pooling** para mejor performance
4. **🔒 Enhanced security** con token refresh
5. **📊 Analytics** de login success/failure rates

---

**📝 Nota:** Este flujo representa el estado actual funcional del sistema con el workaround implementado para manejar la extracción manual de session_id.
