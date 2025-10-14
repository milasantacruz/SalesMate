# 🎨 Crear Iconos Placeholder Temporales

## Opción 1: Usar Icon Kitchen (RECOMENDADO)

1. Ir a: **https://icon.kitchen/**
2. Click en "Create Icon"
3. Seleccionar:
   - **Icon:** Material Design > "shopping_cart" o "store"
   - **Background Color:** #1E88E5 (azul)
   - **Shape:** Circle o Rounded Square
4. Click en "Download"
5. Extraer el ZIP y copiar:
   - `ic_launcher.png` → `assets/icon/app_icon.png`
   - `ic_launcher_foreground.png` → `assets/icon/app_icon_foreground.png`

## Opción 2: Buscar Icono en Flaticon

1. Ir a: **https://www.flaticon.com/**
2. Buscar: "shopping", "sales", "odoo", "pos"
3. Descargar PNG 1024x1024
4. Renombrar a `app_icon.png`
5. Para el foreground, usar el mismo archivo

## Opción 3: Usar Flutter Test Icon

Si solo quieres probar rápido, copia el icono de Flutter:

**Windows PowerShell:**
```powershell
# Copiar icono de Flutter como placeholder
Copy-Item "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" "assets\icon\app_icon.png"
Copy-Item "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" "assets\icon\app_icon_foreground.png"
```

**Nota:** Esto solo es para testing, crea un icono profesional después.

## Opción 4: Crear con Texto Simple (Python)

Si tienes Python instalado:

```python
from PIL import Image, ImageDraw, ImageFont

# Crear icono con fondo
img = Image.new('RGB', (1024, 1024), color='#1E88E5')
d = ImageDraw.Draw(img)

# Agregar texto "OS"
try:
    font = ImageFont.truetype("arial.ttf", 400)
except:
    font = ImageFont.load_default()

text = "OS"
bbox = d.textbbox((0, 0), text, font=font)
w = bbox[2] - bbox[0]
h = bbox[3] - bbox[1]
d.text(((1024-w)/2, (1024-h)/2), text, fill=(255,255,255), font=font)

img.save('assets/icon/app_icon.png')
print("✓ app_icon.png creado")

# Crear foreground transparente
img_fg = Image.new('RGBA', (1024, 1024), color=(0,0,0,0))
d_fg = ImageDraw.Draw(img_fg)
d_fg.text(((1024-w)/2, (1024-h)/2), text, fill=(30,136,229,255), font=font)

img_fg.save('assets/icon/app_icon_foreground.png')
print("✓ app_icon_foreground.png creado")
```

Guardar como `create_icons.py` y ejecutar:
```bash
python create_icons.py
```

---

## 🚀 Después de tener los iconos

```bash
# Instalar dependencias
flutter pub get

# Generar todos los iconos
flutter pub run flutter_launcher_icons

# Ver resultado
flutter run
```

---

## ✅ Verificación

Después de generar, verifica que se crearon en:
```
android/app/src/main/res/
├── mipmap-hdpi/
├── mipmap-mdpi/
├── mipmap-xhdpi/
├── mipmap-xxhdpi/
└── mipmap-xxxhdpi/
```

Cada carpeta debe tener:
- `ic_launcher.png`
- `ic_launcher_foreground.png`
- `ic_launcher_background.png`

