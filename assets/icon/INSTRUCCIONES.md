# 📱 Iconos de la App - Odoo Sales

## 🎨 Archivos Necesarios

Necesitas crear 2 imágenes y colocarlas en esta carpeta (`assets/icon/`):

### 1. **app_icon.png** (1024 x 1024 px)
- **Descripción:** Icono completo con fondo incluido
- **Formato:** PNG con o sin transparencia
- **Tamaño:** 1024 x 1024 píxeles
- **Uso:** Icono legacy para versiones antiguas de Android

### 2. **app_icon_foreground.png** (1024 x 1024 px)
- **Descripción:** Solo el logo/símbolo, SIN fondo
- **Formato:** PNG con transparencia
- **Tamaño:** 1024 x 1024 píxeles
- **Área segura:** El diseño debe estar dentro del círculo central (512 px de radio desde el centro)
- **Uso:** Para iconos adaptativos en Android 8+

---

## 🎨 Opciones para Crear los Iconos

### **Opción 1: Usar Icon Kitchen (Recomendado - Fácil)**

1. Ir a: https://icon.kitchen/
2. Subir tu logo o usar un icono de Material Design
3. Ajustar colores y padding
4. Descargar el pack completo
5. Copiar las imágenes a esta carpeta

### **Opción 2: Diseñar con Figma/Canva**

**Plantilla Figma:**
- Tamaño del canvas: 1024 x 1024 px
- Círculo guía: 512 px de radio (centro: 512, 512)
- Mantener diseño dentro del círculo para seguridad

**Colores Sugeridos para Odoo Sales:**
- Primario: `#1E88E5` (Azul Material)
- Secundario: `#4CAF50` (Verde)
- Alternativo: `#FF9800` (Naranja)

### **Opción 3: Usar un Logo Existente**

Si ya tienes un logo de la empresa:
1. Exportarlo como PNG 1024x1024
2. Para `app_icon.png`: Logo con fondo de color
3. Para `app_icon_foreground.png`: Solo el logo sin fondo (transparente)

---

## 📋 Checklist de Diseño

### `app_icon.png`:
- [ ] Tamaño: 1024 x 1024 px
- [ ] Formato: PNG
- [ ] Logo centrado
- [ ] Fondo de color sólido o degradado
- [ ] Texto legible si lo incluyes

### `app_icon_foreground.png`:
- [ ] Tamaño: 1024 x 1024 px
- [ ] Formato: PNG con transparencia
- [ ] Logo centrado
- [ ] Sin fondo (transparente)
- [ ] Diseño dentro del círculo de 512px de radio

---

## 🚀 Generar Iconos Después

Una vez que tengas las 2 imágenes en esta carpeta:

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Generar todos los iconos
flutter pub run flutter_launcher_icons

# 3. Verificar (opcional)
flutter run
```

---

## 📐 Especificaciones Técnicas

**Android Adaptive Icons:**
- **Foreground:** 1024 x 1024 px (PNG transparente)
- **Background:** Color sólido definido en `pubspec.yaml`
- **Safe Zone:** Círculo de 512px de radio

**Resoluciones Generadas Automáticamente:**
- `mipmap-mdpi`: 48 x 48 px
- `mipmap-hdpi`: 72 x 72 px
- `mipmap-xhdpi`: 96 x 96 px
- `mipmap-xxhdpi`: 144 x 144 px
- `mipmap-xxxhdpi`: 192 x 192 px

---

## 🎨 Ejemplos de Diseño

### Ejemplo 1: Logo Simple
```
app_icon.png:
┌─────────────────┐
│  [Fondo Azul]   │
│                 │
│   [📦 Logo]     │
│                 │
└─────────────────┘

app_icon_foreground.png:
┌─────────────────┐
│  [Transparente] │
│                 │
│   [📦 Logo]     │
│                 │
└─────────────────┘
```

### Ejemplo 2: Logo con Texto
```
app_icon.png:
┌─────────────────┐
│  [Fondo Verde]  │
│   [📦 Logo]     │
│   Odoo Sales    │
└─────────────────┘

app_icon_foreground.png:
┌─────────────────┐
│  [Transparente] │
│   [📦 Logo]     │
│   Odoo Sales    │
└─────────────────┘
```

---

## ⚠️ Errores Comunes

1. **"File not found"**
   - Verifica que los archivos se llamen exactamente:
     - `app_icon.png`
     - `app_icon_foreground.png`

2. **Icono se ve cortado**
   - El diseño debe estar dentro del círculo de 512px de radio

3. **Fondo blanco en foreground**
   - Asegúrate de que `app_icon_foreground.png` tenga transparencia

---

## 🔗 Recursos Útiles

- **Icon Kitchen:** https://icon.kitchen/
- **Material Icons:** https://fonts.google.com/icons
- **Flat Icon:** https://www.flaticon.com/
- **Iconify:** https://icon-sets.iconify.design/

---

**Última actualización:** 2025-10-08

