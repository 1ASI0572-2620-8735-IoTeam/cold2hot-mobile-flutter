import '../models/delivery_models.dart';

class AppStrings {
  final AppLanguage lang;

  const AppStrings(this.lang);

  bool get isEs => lang == AppLanguage.es;

  // Marca y navegación
  String get appTitle => 'Cold2Hot Operador';
  String get navOrders => isEs ? 'Pedidos' : 'Orders';
  String get navActive => isEs ? 'Activo' : 'Active';
  String get navHistory => isEs ? 'Historial' : 'History';
  String get navProfile => isEs ? 'Perfil' : 'Profile';

  // M01 / M02 Login & Recuperar contraseña
  String get loginTitle => isEs ? 'Acceso del repartidor' : 'Courier sign in';
  String get loginSub => isEs
      ? 'Conecta tu turno a la cadena térmica Cold2Hot IoT.'
      : 'Connect your shift to the Cold2Hot IoT thermal chain.';
  String get emailLabel => isEs ? 'Correo operativo' : 'Operator email';
  String get passwordLabel => isEs ? 'Contraseña' : 'Password';
  String get showPwd => isEs ? 'Mostrar' : 'Show';
  String get hidePwd => isEs ? 'Ocultar' : 'Hide';
  String get forgotPassword =>
      isEs ? '¿Olvidaste tu contraseña?' : 'Forgot your password?';
  String get loginBtn => isEs ? 'Iniciar sesión' : 'Sign in';
  String get loginDemoBtn =>
      isEs ? 'Ingresar con cuenta Demo' : 'Sign in with Demo account';
  String get termsPrefix => isEs ? 'Acepto los ' : 'I accept the ';
  String get termsLink => isEs ? 'Términos y Condiciones' : 'Terms & Conditions';
  String get termsMiddle => isEs ? ' y la ' : ' and ';
  String get privacyLink => isEs ? 'Política de Privacidad' : 'Privacy Policy';
  String get termsRequiredError => isEs
      ? 'Debes aceptar los Términos y Condiciones y el uso de ubicación GPS para continuar.'
      : 'You must accept the Terms & Conditions and GPS location policy to continue.';

  // Permisos obligatorios
  String get permsTitle =>
      isEs ? 'Permisos requeridos para repartir' : 'Required permissions to deliver';
  String get permsSub => isEs
      ? 'Cold2Hot necesita tu ubicación GPS en ruta para auditar el trayecto y enlace Bluetooth para la SmartBox.'
      : 'Cold2Hot requires live GPS location for route audit and Bluetooth for SmartBox pairing.';
  String get permGpsTitle =>
      isEs ? 'Ubicación GPS en tiempo real' : 'Live GPS Location';
  String get permGpsDesc => isEs
      ? 'Obligatorio para trazar el trayecto de custodia y mostrar el mapa al cliente.'
      : 'Mandatory to log thermal custody route and display map guidance.';
  String get permBleTitle => isEs ? 'Bluetooth Low Energy' : 'Bluetooth Low Energy';
  String get permBleDesc => isEs
      ? 'Empareja el smartphone con el microcontrolador ESP32 de tu SmartBox.'
      : 'Pairs your phone with the ESP32 controller inside your SmartBox.';
  String get permCamTitle => isEs ? 'Cámara de evidencias' : 'Evidence Camera';
  String get permCamDesc => isEs
      ? 'Captura la fotografía de entrega que cierra la auditoría.'
      : 'Captures delivery photo proof to close the audit.';
  String get grantPermsBtn => isEs ? 'Conceder permisos' : 'Grant permissions';
  String get enableGpsBtn => isEs ? 'Activar GPS' : 'Enable GPS';
  String get continuePermsBtn =>
      isEs ? 'Continuar al turno' : 'Continue to shift';
  String get grantedTag => isEs ? 'Activo' : 'Active';
  String get missingTag => isEs ? 'Pendiente' : 'Required';

  // M03 / M04 Pedidos y detalle
  String get ordersTitle => isEs ? 'Pedidos asignados' : 'Assigned orders';
  String get ordersPendingTag => isEs ? 'Pendiente' : 'Pending';
  String get ordersEmpty =>
      isEs ? 'No tienes entregas pendientes ahora.' : 'No pending deliveries right now.';
  String get orderDetailTitle => isEs ? 'Detalle del envío' : 'Order detail';
  String get restaurantLabel => isEs ? 'Restaurante' : 'Restaurant';
  String get customerLabel => isEs ? 'Cliente' : 'Customer';
  String get addressLabel => isEs ? 'Dirección de entrega' : 'Delivery address';
  String get thermalModeLabel => isEs ? 'Perfil térmico' : 'Thermal profile';
  String get smartBoxLabel => isEs ? 'Caja asignada' : 'Assigned SmartBox';
  String get bleRequiredHint => isEs
      ? 'Se requiere enlace Bluetooth con la caja física para iniciar.'
      : 'Bluetooth pairing with the physical SmartBox is required to start.';
  String get connectSmartBoxCta =>
      isEs ? 'Conectar a la SmartBox' : 'Connect to SmartBox';

  // M05 / M06 / M07 Enlace BLE y Telemetría en ruta
  String get bleConnectTitle =>
      isEs ? 'Enlazar SmartBox (BLE)' : 'Pair SmartBox (BLE)';
  String get bleScanning =>
      isEs ? 'Escaneando señal ESP32 cercana...' : 'Scanning nearby ESP32 beacon...';
  String get bleRescan => isEs ? 'Re-escanear' : 'Scan again';
  String get statusInRoute => isEs ? 'En ruta · Monitoreo activo' : 'In route · Live tracking';
  String get arriveAndUnlock =>
      isEs ? 'Llegué · Desbloquear con OTP' : 'Arrived · Unlock with OTP';
  String get lockLabel => isEs ? 'Cerrojo' : 'Lock';
  String get batteryLabel => isEs ? 'Batería' : 'Battery';
  String get bleLinkLabel => isEs ? 'Enlace BLE' : 'BLE Link';
  String get simulatorTitle =>
      isEs ? 'Laboratorio ciberfísico (ESP32)' : 'Cyber-physical lab (ESP32)';
  String get alertLidOpenTitle =>
      isEs ? 'Advertencia: Tapa abierta en ruta' : 'Warning: Lid opened in transit';
  String get alertTamperTitle =>
      isEs ? 'ALERTA CRÍTICA: Posible manipulación' : 'CRITICAL ALERT: Tamper detected';
  String get alertBreachHint =>
      isEs ? 'Temperatura fuera del rango autorizado' : 'Temperature outside allowed range';

  // M08 / M09 / M10 OTP & Desbloqueo
  String get otpTitle =>
      isEs ? 'Código OTP de entrega' : 'Delivery OTP code';
  String get otpSub => isEs
      ? 'Solicita al cliente los 6 dígitos para abrir el solenoide.'
      : 'Ask the customer for the 6-digit code to unlock the solenoid.';
  String get unlockBtn => isEs ? 'Verificar y abrir caja' : 'Verify & open box';
  String get unlockedTitle =>
      isEs ? '¡SmartBox desbloqueada!' : 'SmartBox unlocked!';
  String get unlockedSub => isEs
      ? 'Entrega el pedido al cliente y toma la foto de evidencia.'
      : 'Hand over the order and capture the proof photo.';
  String get takePhotoBtn =>
      isEs ? 'Tomar foto de evidencia' : 'Capture proof photo';

  // M11 / M12 / M13 Cámara y cierre
  String get cameraTitle =>
      isEs ? 'Fotografía de entrega' : 'Delivery photo proof';
  String get reviewTitle =>
      isEs ? 'Revisar y enviar evidencia' : 'Review & send proof';
  String get retakeBtn => isEs ? 'Volver a tomar' : 'Retake';
  String get confirmSendBtn =>
      isEs ? 'Confirmar entrega' : 'Confirm delivery';
  String get completedTitle =>
      isEs ? 'Entrega completada' : 'Delivery completed';
  String get completedSub => isEs
      ? 'La auditoría térmica y la evidencia han sido registradas.'
      : 'Thermal audit and proof have been logged.';
  String get backToOrders =>
      isEs ? 'Volver a mis pedidos' : 'Back to orders';

  // M14 / M15 Historial y Perfil
  String get historyTitle => isEs ? 'Historial de entregas' : 'Delivery history';
  String get profileTitle => isEs ? 'Perfil y ajustes' : 'Profile & settings';
  String get offlineQueueTitle =>
      isEs ? 'Cola Offline (Store & Forward)' : 'Offline Sync Queue';
  String get logoutBtn => isEs ? 'Cerrar sesión' : 'Sign out';

  String categoryLabel(FoodCategory cat) {
    switch (cat) {
      case FoodCategory.burger:
        return isEs ? 'Hamburguesa' : 'Burger';
      case FoodCategory.pizza:
        return 'Pizza';
      case FoodCategory.hotDrink:
        return isEs ? 'Bebida caliente' : 'Hot drink / Soup';
      case FoodCategory.iceCream:
        return isEs ? 'Helado' : 'Ice cream';
      case FoodCategory.coldDrink:
        return isEs ? 'Bebida fría' : 'Cold drink';
      case FoodCategory.sushi:
        return 'Sushi / Fresh';
    }
  }
}
