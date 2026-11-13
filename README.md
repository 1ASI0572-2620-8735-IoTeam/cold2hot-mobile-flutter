# Cold2Hot Operador — App Móvil Flutter IoT

Aplicación móvil para repartidores de **Cold2Hot**, diseñada para operar en campo con contenedores térmicos inteligentes (**SmartBox ESP32**) mediante Bluetooth Low Energy (BLE), validación de entrega por OTP de 6 dígitos, captura de evidencia fotográfica, geolocalización en ruta y sincronización *Store-and-Forward* con el API Gateway.

## Características principales

- **Autenticación y acceso Demo (`M01`–`M02`):** Login conectado a `POST /api/v1/iam/auth/login`, recuperación de contraseña, selector de servidor (`Render Cloud`, `10.0.2.2`, `Localhost`) y botón **Ingresar con cuenta Demo** (`admin@mirestaurante.pe`).
- **Cumplimiento legal y compuerta de hardware:** Aceptación obligatoria de Términos, Condiciones y Política de Privacidad (`LegalTermsSheet`) y verificación de permisos reales de **GPS en tiempo real** (obligatorio), **Bluetooth LE** y **Cámara** (`PermissionsGateScreen`).
- **Personaje térmico animado (`FoodBuddyWidget`):** Representa cada categoría alimentaria (`BURGER`, `PIZZA`, `HOT_DRINK`, `ICE_CREAM`, `COLD_DRINK`, `SUSHI`) con reacciones visuales en tiempo real según tendencia y rango térmico (frío/escarcha para comida caliente que se enfría; sudor/derretimiento para alimentos fríos que se calientan).
- **Flujo operativo inmersivo (`M03`–`M15`):**
  - `M03`–`M04`: Pedidos asignados, detalle del envío y mapa OpenStreetMap (`flutter_map` + `geolocator`).
  - `M05`–`M07`: Emparejamiento BLE GATT (`flutter_blue_plus`) + radar RSSI, telemetría térmica continua (`DS18B20`), simulador ciberfísico ESP32 y alertas de tapa/intrusión de 2 niveles.
  - `M08`–`M10`: Teclado táctil OTP de 6 dígitos y desbloqueo de solenoide contra `POST /api/v1/security/unlock` (con auto-emisión de OTP de soporte en pedidos semilla).
  - `M11`–`M13`: Captura de fotografía con cámara/galería (`image_picker`), envío en Base64 (`POST /api/v1/orders/:orderId/evidence`) y cierre de entrega.
  - `M14`–`M15`: Historial filtrable, perfil del operador, cambio de idioma (`ES` / `EN`), estado de permisos y cola offline FIFO (`OfflineSyncQueue`).

## Stack técnico

- **Flutter / Dart:** `material_ui`, `google_fonts`, `http`, `shared_preferences`
- **IoT / Hardware / Mapas:** `flutter_blue_plus`, `geolocator`, `permission_handler`, `flutter_map`, `latlong2`, `image_picker`
- **Backend por defecto:** `https://cold2hot-backend.onrender.com/api/v1`

## Comandos útiles

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
