# 🔐 Generar Keystore para Firma de Release

## ⚠️ IMPORTANTE
- **NUNCA pierdas este archivo .jks**
- **NUNCA olvides la contraseña**
- **NUNCA lo subas a Git**
- Si lo pierdes, NO podrás actualizar tu app en Play Store

---

## 📝 Paso 1: Generar el Keystore

### Windows (PowerShell):
```powershell
cd F:\Documents\odoo_test
keytool -genkey -v -keystore android\app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Mac/Linux:
```bash
cd ~/Documents/odoo_test
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

---

## 📋 Paso 2: Responder Preguntas

El comando te pedirá información:

```
Enter keystore password: [TU_CONTRASEÑA_SEGURA]
Re-enter new password: [TU_CONTRASEÑA_SEGURA]

What is your first and last name?
  [Unknown]:  ProAndSys

What is the name of your organizational unit?
  [Unknown]:  Desarrollo

What is the name of your organization?
  [Unknown]:  ProAndSys

What is the name of your City or Locality?
  [Unknown]:  Santiago

What is the name of your State or Province?
  [Unknown]:  RM

What is the two-letter country code for this unit?
  [Unknown]:  CL

Is CN=ProAndSys, OU=Desarrollo, O=ProAndSys, L=Santiago, ST=RM, C=CL correct?
  [no]:  yes

Enter key password for <upload>
        (RETURN if same as keystore password):  [PRESIONAR ENTER]
```

---

## 📝 Paso 3: Crear key.properties

Copiar el archivo de ejemplo:
```bash
# Windows
copy android\key.properties.example android\key.properties

# Mac/Linux
cp android/key.properties.example android/key.properties
```

Editar `android/key.properties` con tus datos:
```properties
storePassword=TU_CONTRASEÑA_AQUÍ
keyPassword=TU_CONTRASEÑA_AQUÍ
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

---

## ✅ Paso 4: Verificar

```bash
# Verificar que el keystore existe
dir android\app\upload-keystore.jks  # Windows
ls android/app/upload-keystore.jks   # Mac/Linux

# Verificar que key.properties existe
dir android\key.properties            # Windows
ls android/key.properties             # Mac/Linux
```

---

## 💾 Paso 5: Backup del Keystore

**¡MUY IMPORTANTE!**

1. Copiar `upload-keystore.jks` a un lugar seguro:
   - USB externa
   - Cloud privado (Google Drive, OneDrive)
   - Gestor de contraseñas (1Password, LastPass)

2. Guardar la contraseña en un lugar seguro

3. **NUNCA** perder este archivo

---

## 🧪 Paso 6: Probar Build de Release

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Si hay errores relacionados con el keystore, revisar:
- Que `android/key.properties` existe
- Que las contraseñas son correctas
- Que `upload-keystore.jks` está en `android/app/`

---

## 📌 Notas Adicionales

- **Validez**: 10000 días (~27 años)
- **Algoritmo**: RSA 2048 bits
- **Alias**: upload
- **Tipo**: JKS (Java KeyStore)

Si necesitas regenerar el keystore, tendrás que:
1. Crear una nueva aplicación en Play Store (nuevo Application ID)
2. O contactar a Google Play Support (muy difícil)

Por eso es **CRÍTICO** no perder este archivo.

